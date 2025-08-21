#!/usr/bin/env python3
"""
Marketplace Readiness Validator for ODIN Integration Connectors
Validates all components are ready for Google Cloud Marketplace submission.
"""

import yaml
import json
from pathlib import Path
import re
import sys

def check_file_exists(path, description):
    """Check if a required file exists."""
    if Path(path).exists():
        print(f'✅ {description}: {path}')
        return True
    else:
        print(f'❌ Missing {description}: {path}')
        return False

def validate_openapi_spec():
    """Validate OpenAPI specification."""
    print('\n🔍 Validating OpenAPI Specification...')
    spec_path = Path('openapi/odin-connector.yaml')
    
    if not spec_path.exists():
        print('❌ OpenAPI spec file not found')
        return False
    
    try:
        with open(spec_path, 'r', encoding='utf-8') as f:
            spec = yaml.safe_load(f)
        
        # Required fields
        required_fields = {
            'openapi': '3.0.0',
            'info.title': 'ODIN Protocol - AI-to-AI Secure Communication Layer',
            'info.version': '1.0.0'
        }
        
        all_valid = True
        for field, expected in required_fields.items():
            keys = field.split('.')
            value = spec
            for key in keys:
                value = value.get(key, {})
            
            if str(value) == str(expected) or (field == 'openapi' and value.startswith('3.0')):
                print(f'✅ {field}: {value}')
            else:
                print(f'❌ {field}: expected "{expected}", got "{value}"')
                all_valid = False
        
        # Check paths
        paths = spec.get('paths', {})
        required_paths = ['/health', '/v1/envelope', '/v1/receipts/hops']
        for path in required_paths:
            if path in paths:
                print(f'✅ Path: {path}')
            else:
                print(f'❌ Missing path: {path}')
                all_valid = False
        
        # Check schemas
        schemas = spec.get('components', {}).get('schemas', {})
        required_schemas = ['HealthResponse', 'EnvelopeRequest', 'Receipt']
        for schema in required_schemas:
            if schema in schemas:
                print(f'✅ Schema: {schema}')
            else:
                print(f'❌ Missing schema: {schema}')
                all_valid = False
        
        return all_valid
        
    except Exception as e:
        print(f'❌ OpenAPI validation error: {e}')
        return False

def validate_terraform_config():
    """Validate Terraform configuration."""
    print('\n🔍 Validating Terraform Configuration...')
    tf_path = Path('terraform/integration-connector.tf')
    
    if not tf_path.exists():
        print('❌ Terraform config file not found')
        return False
    
    try:
        with open(tf_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check for required resources
        required_resources = [
            'google_integration_connectors_custom_connector',
            'google_integration_connectors_connection',
            'google_service_account',
            'google_cloud_run_service_iam_member'
        ]
        
        all_valid = True
        for resource in required_resources:
            if resource in content:
                print(f'✅ Resource: {resource}')
            else:
                print(f'❌ Missing resource: {resource}')
                all_valid = False
        
        # Check for google-beta provider
        if 'google-beta' in content:
            print('✅ Google Beta provider configured')
        else:
            print('❌ Missing google-beta provider')
            all_valid = False
        
        # Check for variables
        variables = re.findall(r'variable\s+"([^"]+)"', content)
        required_vars = ['project_id', 'region']
        for var in required_vars:
            if var in variables:
                print(f'✅ Variable: {var}')
            else:
                print(f'❌ Missing variable: {var}')
                all_valid = False
        
        return all_valid
        
    except Exception as e:
        print(f'❌ Terraform validation error: {e}')
        return False

def validate_documentation():
    """Validate documentation files."""
    print('\n🔍 Validating Documentation...')
    
    required_docs = [
        ('README.md', 'Main README'),
        ('docs/CONNECTOR_README.md', 'Connector Documentation'),
        ('marketplace/integration-connectors.md', 'Marketplace Documentation'),
        ('integration-connectors-README.md', 'Integration Setup Guide'),
        ('LICENSE', 'License File'),
        ('CHANGELOG.md', 'Changelog')
    ]
    
    all_valid = True
    for path, description in required_docs:
        if not check_file_exists(path, description):
            all_valid = False
    
    return all_valid

def validate_scripts():
    """Validate deployment and test scripts."""
    print('\n🔍 Validating Scripts...')
    
    required_scripts = [
        ('scripts/deploy-integration-connector.ps1', 'Main Deployment Script'),
        ('scripts/test-endpoints.ps1', 'Endpoint Test Script'),
        ('scripts/identity-token.ps1', 'Token Generation Script'),
        ('scripts/validate_openapi.py', 'OpenAPI Validator'),
        ('scripts/validate_terraform.py', 'Terraform Validator')
    ]
    
    all_valid = True
    for path, description in required_scripts:
        if not check_file_exists(path, description):
            all_valid = False
    
    return all_valid

def validate_test_configurations():
    """Validate test configurations."""
    print('\n🔍 Validating Test Configurations...')
    
    required_configs = [
        ('.vscode/odin.http', 'VS Code REST Client'),
        ('iam/policy.yaml', 'IAM Policy Configuration')
    ]
    
    all_valid = True
    for path, description in required_configs:
        if not check_file_exists(path, description):
            all_valid = False
    
    return all_valid

def validate_marketplace_requirements():
    """Validate marketplace-specific requirements."""
    print('\n🔍 Validating Marketplace Requirements...')
    
    # Check for marketplace documentation
    marketplace_path = Path('marketplace/integration-connectors.md')
    if not marketplace_path.exists():
        print('❌ Missing marketplace documentation')
        return False
    
    try:
        with open(marketplace_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        required_sections = [
            'Overview',
            'Key Features', 
            'Quick Start',
            'Security Model',
            'API Endpoints',
            'Support'
        ]
        
        all_valid = True
        for section in required_sections:
            if f'## {section}' in content or f'### {section}' in content:
                print(f'✅ Marketplace section: {section}')
            else:
                print(f'❌ Missing marketplace section: {section}')
                all_valid = False
        
        # Check for required metadata
        if 'Apache 2.0' in content:
            print('✅ License information present')
        else:
            print('❌ Missing license information')
            all_valid = False
        
        if 'Google Cloud' in content:
            print('✅ Google Cloud integration mentioned')
        else:
            print('❌ Missing Google Cloud integration details')
            all_valid = False
        
        return all_valid
        
    except Exception as e:
        print(f'❌ Marketplace documentation error: {e}')
        return False

def main():
    """Run all validations."""
    print('🔍 ODIN Integration Connectors - Marketplace Readiness Check')
    print('=' * 60)
    
    validators = [
        validate_openapi_spec,
        validate_terraform_config,
        validate_documentation,
        validate_scripts,
        validate_test_configurations,
        validate_marketplace_requirements
    ]
    
    results = []
    for validator in validators:
        try:
            result = validator()
            results.append(result)
        except Exception as e:
            print(f'❌ Validator error: {e}')
            results.append(False)
    
    print('\n' + '=' * 60)
    print('📋 VALIDATION SUMMARY')
    print('=' * 60)
    
    validation_names = [
        'OpenAPI Specification',
        'Terraform Configuration', 
        'Documentation Files',
        'Deployment Scripts',
        'Test Configurations',
        'Marketplace Requirements'
    ]
    
    passed = 0
    for i, (name, result) in enumerate(zip(validation_names, results)):
        status = '✅ PASS' if result else '❌ FAIL'
        print(f'{status} {name}')
        if result:
            passed += 1
    
    print('\n' + '=' * 60)
    
    if all(results):
        print('🎉 ALL VALIDATIONS PASSED!')
        print('✅ Ready for Google Cloud Marketplace submission')
        print('\nNext steps:')
        print('1. Test deployment: ./scripts/deploy-integration-connector.ps1')
        print('2. Submit to marketplace: Follow Google Cloud Marketplace guidelines')
        print('3. Monitor deployment: Check Cloud Console for any issues')
        return True
    else:
        print(f'❌ {len(results) - passed} of {len(results)} validations failed')
        print('⚠️  Fix the issues above before marketplace submission')
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
