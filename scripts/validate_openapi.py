#!/usr/bin/env python3
"""
OpenAPI Specification Validator for ODIN Connector
Validates the YAML syntax and structure of the OpenAPI spec.
"""

import yaml
import json
from pathlib import Path
import sys

def validate_openapi_spec():
    """Validate the OpenAPI specification file."""
    spec_path = Path('openapi/odin-connector.yaml')
    
    if not spec_path.exists():
        print('❌ OpenAPI spec file not found at openapi/odin-connector.yaml')
        return False
    
    try:
        with open(spec_path, 'r', encoding='utf-8') as f:
            spec = yaml.safe_load(f)
        
        print('✅ OpenAPI YAML syntax is valid')
        print(f'📋 API Title: {spec.get("info", {}).get("title", "Unknown")}')
        print(f'📋 API Version: {spec.get("info", {}).get("version", "Unknown")}')
        print(f'📋 Paths defined: {len(spec.get("paths", {}))}')
        print(f'📋 Components schemas: {len(spec.get("components", {}).get("schemas", {}))}')
        
        # Check for required sections
        required_sections = ['openapi', 'info', 'paths', 'components']
        all_present = True
        
        for section in required_sections:
            if section in spec:
                print(f'✅ Required section "{section}" present')
            else:
                print(f'❌ Missing required section "{section}"')
                all_present = False
        
        # Validate paths have required methods
        paths = spec.get('paths', {})
        for path, methods in paths.items():
            print(f'📍 Path: {path}')
            for method, details in methods.items():
                if method.upper() in ['GET', 'POST', 'PUT', 'DELETE']:
                    summary = details.get('summary', 'No summary')
                    print(f'  ✅ Method {method.upper()}: {summary}')
        
        # Check schemas
        schemas = spec.get('components', {}).get('schemas', {})
        for schema_name, schema_def in schemas.items():
            properties_count = len(schema_def.get('properties', {}))
            print(f'📊 Schema "{schema_name}": {properties_count} properties')
        
        print('\n🎉 OpenAPI specification validation complete!')
        return all_present
        
    except yaml.YAMLError as e:
        print(f'❌ YAML parsing error: {e}')
        return False
    except Exception as e:
        print(f'❌ Validation error: {e}')
        return False

if __name__ == '__main__':
    success = validate_openapi_spec()
    sys.exit(0 if success else 1)
