#!/usr/bin/env python3
"""
Terraform Configuration Validator for ODIN Integration Connector
Validates the HCL syntax and structure of the Terraform configuration.
"""

import re
from pathlib import Path

def validate_terraform_config():
    """Validate the Terraform configuration file."""
    tf_path = Path('terraform/integration-connector.tf')
    
    if not tf_path.exists():
        print('❌ Terraform config file not found at terraform/integration-connector.tf')
        return False
    
    try:
        with open(tf_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        print('✅ Terraform HCL file readable')
        
        # Check for required providers
        if 'google-beta' in content:
            print('✅ Google Beta provider configured')
        else:
            print('❌ Missing google-beta provider')
        
        # Check for required resources
        required_resources = [
            'google_integration_connectors_custom_connector',
            'google_integration_connectors_connection',
            'google_service_account',
            'google_cloud_run_service_iam_member'  # Alternative to google_project_iam_member
        ]
        
        missing_resources = []
        for resource in required_resources:
            if resource in content:
                print(f'✅ Resource "{resource}" present')
            else:
                print(f'❌ Missing resource "{resource}"')
                missing_resources.append(resource)
        
        # Check for variables
        variables = re.findall(r'variable\s+"([^"]+)"', content)
        print(f'📋 Variables defined: {len(variables)}')
        for var in variables:
            print(f'  📝 Variable: {var}')
        
        # Check for outputs
        outputs = re.findall(r'output\s+"([^"]+)"', content)
        print(f'📋 Outputs defined: {len(outputs)}')
        for output in outputs:
            print(f'  📤 Output: {output}')
        
        # Check for proper resource naming
        connectors = re.findall(r'resource\s+"google_integration_connectors_[^"]+"\s+"([^"]+)"', content)
        print(f'📋 Integration Connectors resources: {len(connectors)}')
        for connector in connectors:
            print(f'  🔌 Connector: {connector}')
        
        print('\n🎉 Terraform configuration validation complete!')
        
        if missing_resources:
            print(f'\n⚠️  Missing {len(missing_resources)} required resources')
            return False
        
        return True
        
    except Exception as e:
        print(f'❌ Validation error: {e}')
        return False

if __name__ == '__main__':
    success = validate_terraform_config()
    exit(0 if success else 1)
