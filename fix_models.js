const fs = require('fs');
const path = require('path');
const https = require('https');

// Load environment variables
const envPath = path.join(__dirname, '.env');
let replicateApiToken = '';
if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    const tokenMatch = envContent.match(/REPLICATE_API_TOKEN=(.+)/);
    if (tokenMatch) {
        replicateApiToken = tokenMatch[1].trim();
    }
}

if (!replicateApiToken) {
    console.error("REPLICATE_API_TOKEN not found in .env");
    process.exit(1);
}

const fetchModelSchema = (owner, name) => {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.replicate.com',
            path: `/v1/models/${owner}/${name}`,
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${replicateApiToken}`
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                if (res.statusCode === 200) {
                    try {
                        resolve(JSON.parse(data));
                    } catch (e) {
                        reject(e);
                    }
                } else {
                    reject(new Error(`Failed with status code ${res.statusCode}: ${data}`));
                }
            });
        });

        req.on('error', (e) => reject(e));
        req.end();
    });
};

const validateAndFix = async (filePath) => {
    if (!fs.existsSync(filePath)) {
        console.log(`File not found: ${filePath}`);
        return;
    }
    
    console.log(`Processing ${filePath}...`);
    let data;
    try {
        data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch(e) {
        console.error(`Failed to parse ${filePath}:`, e);
        return;
    }
    
    let modified = false;

    for (let model of data) {
        if (!model.url) continue;
        
        const urlMatch = model.url.match(/models\/([^\/]+)\/([^\/]+)\/predictions/);
        if (!urlMatch) continue;
        
        const owner = urlMatch[1];
        const name = urlMatch[2];
        
        console.log(`Checking model: ${owner}/${name}`);
        
        try {
            const schemaData = await fetchModelSchema(owner, name);
            if (schemaData.latest_version && schemaData.latest_version.openapi_schema) {
                const schemas = schemaData.latest_version.openapi_schema.components.schemas;
                
                // Check aspect_ratio
                if (schemas.aspect_ratio && schemas.aspect_ratio.enum) {
                    const validRatios = schemas.aspect_ratio.enum;
                    if (!model.options) model.options = {};
                    
                    // Compare arrays
                    const currentRatios = model.options.aspect_ratios || [];
                    if (JSON.stringify(currentRatios) !== JSON.stringify(validRatios)) {
                        console.log(`  Fixing aspect_ratios for ${model.id}`);
                        model.options.aspect_ratios = validRatios;
                        modified = true;
                    }
                }
                
                // Check output_format
                if (schemas.output_format && schemas.output_format.enum) {
                    const validFormats = schemas.output_format.enum;
                    if (model.request_body && model.request_body.input && model.request_body.input.output_format) {
                        const currentFormat = model.request_body.input.output_format;
                        if (!validFormats.includes(currentFormat)) {
                            console.log(`  Fixing output_format for ${model.id} from '${currentFormat}' to '${validFormats[0]}'`);
                            model.request_body.input.output_format = validFormats[0];
                            modified = true;
                        }
                    }
                }
                
                // Check resolution if exists
                if (schemas.resolution && schemas.resolution.enum) {
                    const validRes = schemas.resolution.enum;
                    if (!model.options) model.options = {};
                    
                    const currentRes = model.options.resolutions || [];
                    if (JSON.stringify(currentRes) !== JSON.stringify(validRes)) {
                        console.log(`  Fixing resolutions for ${model.id}`);
                        model.options.resolutions = validRes;
                        modified = true;
                    }
                }
            }
        } catch (e) {
            console.error(`  Error fetching schema for ${owner}/${name}: ${e.message}`);
        }
    }
    
    if (modified) {
        fs.writeFileSync(filePath, JSON.stringify(data, null, 4));
        console.log(`Updated ${filePath}`);
    } else {
        console.log(`No changes needed for ${filePath}`);
    }
};

(async () => {
    await validateAndFix(path.join(__dirname, 'image.json'));
    await validateAndFix(path.join(__dirname, 'Prompts.json'));
    console.log('Done!');
})();
