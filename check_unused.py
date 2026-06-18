import os
import yaml
import re

def find_unused_dependencies():
    pubspec_path = "pubspec.yaml"
    if not os.path.exists(pubspec_path):
        print("No pubspec.yaml found")
        return

    with open(pubspec_path, 'r', encoding='utf-8') as f:
        pubspec = yaml.safe_load(f)

    deps = pubspec.get('dependencies', {})
    
    # Packages to ignore (standard flutter packages or ones that might not be imported directly but used)
    ignore_list = ['flutter', 'flutter_localizations', 'cupertino_icons', 'pro_image_editor']
    
    packages_to_check = []
    for dep, val in deps.items():
        if dep not in ignore_list:
            packages_to_check.append(dep)

    # find all dart files
    dart_files = []
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))

    # Read all dart file contents
    dart_contents = ""
    for df in dart_files:
        with open(df, 'r', encoding='utf-8') as f:
            dart_contents += f.read() + "\n"

    unused = []
    for pkg in packages_to_check:
        # Check if imported, e.g., import 'package:pkg_name/...';
        # or import 'package:pkg_name.dart';
        pattern = r"import\s+['\"]package:" + re.escape(pkg) + r"[/']"
        if not re.search(pattern, dart_contents):
            unused.append(pkg)

    print("Unused dependencies based on imports:")
    for u in unused:
        print(u)

if __name__ == "__main__":
    find_unused_dependencies()
