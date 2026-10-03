#!/usr/bin/env python3
"""Generate a dependency-free Xcode 16+ project with synchronized source groups."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / 'KaX.xcodeproj'
PROJECT.mkdir(exist_ok=True)
objects = {}

def ident(number):
    return f'{number:024X}'

def add(number, value):
    objects[ident(number)] = value
    return ident(number)

def quoted(value):
    if isinstance(value, dict):
        return '{ ' + ' '.join(f'{k} = {quoted(v)};' for k, v in value.items()) + ' }'
    if isinstance(value, list):
        return '( ' + ', '.join(quoted(v) for v in value) + ', )' if value else '()'
    return json.dumps(str(value), ensure_ascii=False)

app, tests, ui = ident(10), ident(11), ident(12)
products = []
groups = []
for index, (name, extension) in enumerate([('KaX', 'app'), ('KaXTests', 'xctest'), ('KaXUITests', 'xctest')]):
    products.append(add(20 + index, {'isa': 'PBXFileReference', 'explicitFileType': 'wrapper.application' if index == 0 else 'wrapper.cfbundle', 'includeInIndex': 0, 'path': f'{name}.{extension}', 'sourceTree': 'BUILT_PRODUCTS_DIR'}))
    groups.append(add(30 + index, {'isa': 'PBXFileSystemSynchronizedRootGroup', 'path': name, 'sourceTree': '<group>'}))
products_group = add(40, {'isa': 'PBXGroup', 'children': products, 'name': 'Products', 'sourceTree': '<group>'})
root_group = add(41, {'isa': 'PBXGroup', 'children': groups + [products_group], 'sourceTree': '<group>'})

project_settings = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO', 'CLANG_ENABLE_MODULES': 'YES',
    'CLANG_ENABLE_OBJC_ARC': 'YES', 'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES',
    'GCC_C_LANGUAGE_STANDARD': 'gnu17', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
    'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0', 'SWIFT_STRICT_CONCURRENCY': 'complete',
}

def config_list(base, settings):
    ids = []
    for offset, name in enumerate(['Debug', 'Release']):
        configured = dict(settings)
        configured.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O',
                           'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym'})
        if name == 'Debug':
            configured.update({'ENABLE_TESTABILITY': 'YES', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG $(inherited)', 'ONLY_ACTIVE_ARCH': 'YES'})
        else:
            configured['SWIFT_COMPILATION_MODE'] = 'wholemodule'
        ids.append(add(base + offset, {'isa': 'XCBuildConfiguration', 'buildSettings': configured, 'name': name}))
    return add(base + 2, {'isa': 'XCConfigurationList', 'buildConfigurations': ids, 'defaultConfigurationIsVisible': 0, 'defaultConfigurationName': 'Release'})

project_configs = config_list(50, project_settings)
for index, name in enumerate(['KaX', 'KaXTests', 'KaXUITests']):
    settings = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': f'com.doyoulikelin.kax{("." + name) if index else ""}', 'GENERATE_INFOPLIST_FILE': 'YES', 'TARGETED_DEVICE_FAMILY': '1,2', 'CODE_SIGN_STYLE': 'Automatic', 'SWIFT_EMIT_LOC_STRINGS': 'YES'}
    if index == 0:
        settings.update({
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
            'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '0.1.0',
            'INFOPLIST_KEY_CFBundleDisplayName': 'kaX', 'INFOPLIST_KEY_LSApplicationCategoryType': 'public.app-category.healthcare-fitness',
            'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
            'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents': 'YES',
            'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
            'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone': 'UIInterfaceOrientationPortrait',
            'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad': 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
            'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
            'ENABLE_PREVIEWS': 'YES', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
            'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD': 'NO',
        })
    else:
        settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'
        if index == 1:
            settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/KaX.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/KaX'
            settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
        else:
            settings['TEST_TARGET_NAME'] = 'KaX'
    target_configs = config_list(60 + index * 10, settings)
    phases = []
    for offset, isa in enumerate(['PBXSourcesBuildPhase', 'PBXFrameworksBuildPhase', 'PBXResourcesBuildPhase']):
        phases.append(add(100 + index * 10 + offset, {'isa': isa, 'buildActionMask': 2147483647, 'files': [], 'runOnlyForDeploymentPostprocessing': 0}))
    dependencies = []
    if index:
        proxy = add(150 + index, {'isa': 'PBXContainerItemProxy', 'containerPortal': ident(1), 'proxyType': 1, 'remoteGlobalIDString': app, 'remoteInfo': 'KaX'})
        dependencies.append(add(160 + index, {'isa': 'PBXTargetDependency', 'target': app, 'targetProxy': proxy}))
    add(10 + index, {'isa': 'PBXNativeTarget', 'buildConfigurationList': target_configs, 'buildPhases': phases, 'buildRules': [], 'dependencies': dependencies, 'fileSystemSynchronizedGroups': [groups[index]], 'name': name, 'packageProductDependencies': [], 'productName': name, 'productReference': products[index], 'productType': ['com.apple.product-type.application', 'com.apple.product-type.bundle.unit-test', 'com.apple.product-type.bundle.ui-testing'][index]})

add(1, {'isa': 'PBXProject', 'attributes': {'BuildIndependentTargetsInParallel': 'YES', 'LastSwiftUpdateCheck': '2630', 'LastUpgradeCheck': '2630', 'TargetAttributes': {app: {'CreatedOnToolsVersion': '26.3'}, tests: {'CreatedOnToolsVersion': '26.3', 'TestTargetID': app}, ui: {'CreatedOnToolsVersion': '26.3', 'TestTargetID': app}}}, 'buildConfigurationList': project_configs, 'developmentRegion': 'zh-Hans', 'hasScannedForEncodings': 0, 'knownRegions': ['zh-Hans', 'en', 'Base'], 'mainGroup': root_group, 'minimizedProjectReferenceProxies': 1, 'preferredProjectObjectVersion': 77, 'productRefGroup': products_group, 'projectDirPath': '', 'projectRoot': '', 'targets': [app, tests, ui]})

text = '// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 77;\n objects = {\n'
text += '\n'.join(f' {key} = {quoted(value)};' for key, value in objects.items())
text += f'\n }};\n rootObject = {ident(1)};\n}}\n'
(PROJECT / 'project.pbxproj').write_text(text)

scheme_dir = PROJECT / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
ref = lambda target, name, product: f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:KaX.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app, 'KaX', 'KaX.app')}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
  <Testables><TestableReference skipped="NO" parallelizable="NO">{ref(tests, 'KaXTests', 'KaXTests.xctest')}</TestableReference><TestableReference skipped="NO" parallelizable="NO">{ref(ui, 'KaXUITests', 'KaXUITests.xctest')}</TestableReference></Testables>
 </TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app, 'KaX', 'KaX.app')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app, 'KaX', 'KaX.app')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(scheme_dir / 'KaX.xcscheme').write_text(scheme)
print('Generated KaX.xcodeproj')
