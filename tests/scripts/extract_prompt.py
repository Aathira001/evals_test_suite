#!/usr/bin/env python3

import yaml
import sys
from pathlib import Path

def extract_prompt_to_markdown(yaml_file_path):
    """Extract prompt content from YAML file and save as markdown."""
    
    yaml_path = Path(yaml_file_path)
    if not yaml_path.exists():
        print(f"Error: File {yaml_file_path} not found")
        return False
    
    try:
        with open(yaml_path, 'r', encoding='utf-8') as file:
            data = yaml.safe_load(file)
        
        # Extract name and prompt
        name = data.get('name', 'unnamed')
        prompt_content = data.get('prompt', '')
        
        if not prompt_content:
            print("Error: No 'prompt' field found in YAML")
            return False
        
        # Create markdown filename
        md_filename = f"{name}.md"
        md_path = yaml_path.parent / md_filename
        
        # Write prompt content to markdown file
        with open(md_path, 'w', encoding='utf-8') as md_file:
            md_file.write(prompt_content)
        
        print(f"Successfully extracted prompt to: {md_path}")
        return True
        
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python extract_prompt.py <yaml_file_path>")
        sys.exit(1)
    
    yaml_file_path = sys.argv[1]
    success = extract_prompt_to_markdown(yaml_file_path)
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()