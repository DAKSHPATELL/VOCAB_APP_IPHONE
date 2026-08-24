#!/usr/bin/env python3
"""Generates VocabWallpaper.xcodeproj from the folders on disk.

Hand-maintaining a pbxproj is how merge conflicts and dangling file references
happen. This walks App/ and Widget/, assigns stable IDs derived from each
object's path, and writes the whole project out. Re-run it after adding files.

Run:  python3 tools/generate_xcodeproj.py
"""

import hashlib
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = ROOT / "VocabWallpaper.xcodeproj"

APP_NAME = "VocabWallpaper"
WIDGET_NAME = "VocabWidgetExtension"
APP_BUNDLE_ID = "com.dakshpatel.vocabwallpaper"
WIDGET_BUNDLE_ID = "com.dakshpatel.vocabwallpaper.widget"
DEPLOYMENT_TARGET = "17.0"
MARKETING_VERSION = "1.0"
PROJECT_VERSION = "1"

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcassets": "folder.assetcatalog",
    ".json": "text.json",
    ".png": "image.png",
    ".md": "net.daringfireball.markdown",
}

used_ids = {}


def oid(key):
    """Stable 24-hex-digit object id derived from a semantic key."""
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:24].upper()
    if digest in used_ids and used_ids[digest] != key:
        raise SystemExit(f"id collision between {used_ids[digest]!r} and {key!r}")
    used_ids[digest] = key
    return digest


class Node:
    """One entry in the project navigator."""

    def __init__(self, path: pathlib.Path, relative: str):
        self.path = path
        self.relative = relative
        self.name = path.name
        self.is_group = path.is_dir() and path.suffix != ".xcassets"
        self.children = []
        self.id = oid(f"file:{relative}")
        self.build_id = oid(f"build:{relative}")

    @property
    def file_type(self):
        return FILE_TYPES.get(self.path.suffix, "text")

    @property
    def is_source(self):
        return self.path.suffix == ".swift"

    @property
    def is_resource(self):
        return self.path.suffix in {".xcassets", ".png"} and not self.is_group


def scan(directory: pathlib.Path, relative_prefix: str) -> Node:
    node = Node(directory, relative_prefix)
    for child in sorted(directory.iterdir(), key=lambda p: (p.is_file(), p.name.lower())):
        if child.name.startswith("."):
            continue
        child_relative = f"{relative_prefix}/{child.name}"
        if child.is_dir() and child.suffix != ".xcassets":
            node.children.append(scan(child, child_relative))
        else:
            node.children.append(Node(child, child_relative))
    return node


def flatten(node: Node):
    yield node
    for child in node.children:
        if child.is_group:
            yield from flatten(child)
        else:
            yield child


def sources(node: Node):
    return [n for n in flatten(node) if n.is_source]


def resources(node: Node):
    return [n for n in flatten(node) if n.is_resource and n.path.suffix == ".xcassets"]


def groups(node: Node):
    return [n for n in flatten(node) if n.is_group]


# --------------------------------------------------------------------- emit

def build_file_lines(nodes, comment_suffix):
    return "\n".join(
        f"\t\t{n.build_id} /* {n.name} in {comment_suffix} */ = {{isa = PBXBuildFile; "
        f"fileRef = {n.id} /* {n.name} */; }};"
        for n in nodes
    )


def file_reference_lines(nodes):
    lines = []
    for n in nodes:
        lines.append(
            f"\t\t{n.id} /* {n.name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {n.file_type}; path = {quote(n.name)}; "
            f"sourceTree = \"<group>\"; }};"
        )
    return "\n".join(lines)


def quote(value):
    safe = all(c.isalnum() or c in "._/-" for c in value)
    return value if safe else f'"{value}"'


def group_lines(node: Node, root=False):
    children = "\n".join(
        f"\t\t\t\t{child.id} /* {child.name} */," for child in node.children
    )
    path_line = "" if root else f"\n\t\t\tpath = {quote(node.name)};"
    return (
        f"\t\t{node.id} /* {node.name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{children}\n\t\t\t);{path_line}\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )


def phase_files(nodes, suffix):
    return "\n".join(
        f"\t\t\t\t{n.build_id} /* {n.name} in {suffix} */," for n in nodes
    )


def main():
    app_root = scan(ROOT / "App", "App")
    widget_root = scan(ROOT / "Widget", "Widget")

    app_sources = sources(app_root)
    app_resources = resources(app_root)
    widget_sources = sources(widget_root)

    ids = {key: oid(key) for key in [
        "project", "mainGroup", "productsGroup", "frameworksGroup",
        "appTarget", "widgetTarget",
        "appProduct", "widgetProduct",
        "appSources", "appFrameworks", "appResources", "appEmbed",
        "widgetSources", "widgetFrameworks", "widgetResources",
        "appConfigList", "widgetConfigList", "projectConfigList",
        "appDebug", "appRelease", "widgetDebug", "widgetRelease",
        "projectDebug", "projectRelease",
        "widgetDependency", "widgetProxy",
        "packageRef", "appPackageProduct", "widgetPackageProduct",
        "appPackageBuildFile", "widgetPackageBuildFile", "widgetEmbedBuildFile",
    ]}

    all_file_nodes = [n for n in list(flatten(app_root)) + list(flatten(widget_root))
                      if not n.is_group]

    text = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 60;
	objects = {{

/* Begin PBXBuildFile section */
{build_file_lines(app_sources, "Sources")}
{build_file_lines(widget_sources, "Sources")}
{build_file_lines(app_resources, "Resources")}
		{ids["appPackageBuildFile"]} /* VocabKit in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids["appPackageProduct"]} /* VocabKit */; }};
		{ids["widgetPackageBuildFile"]} /* VocabKit in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids["widgetPackageProduct"]} /* VocabKit */; }};
		{ids["widgetEmbedBuildFile"]} /* {WIDGET_NAME}.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {ids["widgetProduct"]} /* {WIDGET_NAME}.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{ids["widgetProxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids["project"]} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids["widgetTarget"]};
			remoteInfo = {WIDGET_NAME};
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		{ids["appEmbed"]} /* Embed Foundation Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				{ids["widgetEmbedBuildFile"]} /* {WIDGET_NAME}.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
{file_reference_lines(all_file_nodes)}
		{ids["appProduct"]} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{ids["widgetProduct"]} /* {WIDGET_NAME}.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = {WIDGET_NAME}.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{ids["appFrameworks"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids["appPackageBuildFile"]} /* VocabKit in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids["widgetFrameworks"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids["widgetPackageBuildFile"]} /* VocabKit in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{ids["mainGroup"]} = {{
			isa = PBXGroup;
			children = (
				{app_root.id} /* App */,
				{widget_root.id} /* Widget */,
				{ids["frameworksGroup"]} /* Frameworks */,
				{ids["productsGroup"]} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids["productsGroup"]} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids["appProduct"]} /* {APP_NAME}.app */,
				{ids["widgetProduct"]} /* {WIDGET_NAME}.appex */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{ids["frameworksGroup"]} /* Frameworks */ = {{
			isa = PBXGroup;
			children = (
			);
			name = Frameworks;
			sourceTree = "<group>";
		}};
{chr(10).join(group_lines(g) for g in groups(app_root))}
{chr(10).join(group_lines(g) for g in groups(widget_root))}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids["appTarget"]} /* {APP_NAME} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids["appConfigList"]} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */;
			buildPhases = (
				{ids["appSources"]} /* Sources */,
				{ids["appFrameworks"]} /* Frameworks */,
				{ids["appResources"]} /* Resources */,
				{ids["appEmbed"]} /* Embed Foundation Extensions */,
			);
			buildRules = (
			);
			dependencies = (
				{ids["widgetDependency"]} /* PBXTargetDependency */,
			);
			name = {APP_NAME};
			packageProductDependencies = (
				{ids["appPackageProduct"]} /* VocabKit */,
			);
			productName = {APP_NAME};
			productReference = {ids["appProduct"]} /* {APP_NAME}.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids["widgetTarget"]} /* {WIDGET_NAME} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids["widgetConfigList"]} /* Build configuration list for PBXNativeTarget "{WIDGET_NAME}" */;
			buildPhases = (
				{ids["widgetSources"]} /* Sources */,
				{ids["widgetFrameworks"]} /* Frameworks */,
				{ids["widgetResources"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = {WIDGET_NAME};
			packageProductDependencies = (
				{ids["widgetPackageProduct"]} /* VocabKit */,
			);
			productName = {WIDGET_NAME};
			productReference = {ids["widgetProduct"]} /* {WIDGET_NAME}.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids["project"]} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{ids["appTarget"]} = {{
						CreatedOnToolsVersion = 16.0;
					}};
					{ids["widgetTarget"]} = {{
						CreatedOnToolsVersion = 16.0;
					}};
				}};
			}};
			buildConfigurationList = {ids["projectConfigList"]} /* Build configuration list for PBXProject "{APP_NAME}" */;
			compatibilityVersion = "Xcode 15.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids["mainGroup"]};
			packageReferences = (
				{ids["packageRef"]} /* XCLocalSwiftPackageReference "VocabKit" */,
			);
			productRefGroup = {ids["productsGroup"]} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids["appTarget"]} /* {APP_NAME} */,
				{ids["widgetTarget"]} /* {WIDGET_NAME} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids["appResources"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{phase_files(app_resources, "Resources")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids["widgetResources"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids["appSources"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{phase_files(app_sources, "Sources")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids["widgetSources"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{phase_files(widget_sources, "Sources")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{ids["widgetDependency"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids["widgetTarget"]} /* {WIDGET_NAME} */;
			targetProxy = {ids["widgetProxy"]} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{ids["projectDebug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{ids["projectRelease"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{ids["appDebug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{app_target_settings()}
			}};
			name = Debug;
		}};
		{ids["appRelease"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{app_target_settings()}
			}};
			name = Release;
		}};
		{ids["widgetDebug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{widget_target_settings()}
			}};
			name = Debug;
		}};
		{ids["widgetRelease"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{widget_target_settings()}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids["projectConfigList"]} /* Build configuration list for PBXProject "{APP_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["projectDebug"]} /* Debug */,
				{ids["projectRelease"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids["appConfigList"]} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["appDebug"]} /* Debug */,
				{ids["appRelease"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids["widgetConfigList"]} /* Build configuration list for PBXNativeTarget "{WIDGET_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["widgetDebug"]} /* Debug */,
				{ids["widgetRelease"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{ids["packageRef"]} /* XCLocalSwiftPackageReference "VocabKit" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = VocabKit;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{ids["appPackageProduct"]} /* VocabKit */ = {{
			isa = XCSwiftPackageProductDependency;
			productName = VocabKit;
		}};
		{ids["widgetPackageProduct"]} /* VocabKit */ = {{
			isa = XCSwiftPackageProductDependency;
			productName = VocabKit;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {ids["project"]} /* Project object */;
}}
"""

    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(text, encoding="utf-8")

    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(parents=True, exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace\n   version = "1.0">\n'
        '   <FileRef\n      location = "self:">\n   </FileRef>\n'
        '</Workspace>\n',
        encoding="utf-8",
    )
    (workspace / "xcshareddata").mkdir(parents=True, exist_ok=True)
    (workspace / "xcshareddata" / "IDEWorkspaceChecks.plist").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n'
        '\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n'
        '</dict>\n</plist>\n',
        encoding="utf-8",
    )

    schemes = PROJECT / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (schemes / f"{APP_NAME}.xcscheme").write_text(
        scheme_xml(ids["appTarget"]), encoding="utf-8"
    )

    print(f"wrote {PROJECT.relative_to(ROOT)}")
    print(f"  app target:    {len(app_sources)} swift files, "
          f"{len(app_resources)} resource bundles")
    print(f"  widget target: {len(widget_sources)} swift files")


def app_target_settings():
    return "\n".join("\t\t\t\t" + line for line in [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_ENTITLEMENTS = App/VocabWallpaper/VocabWallpaper.entitlements;",
        "CODE_SIGN_STYLE = Automatic;",
        f'CURRENT_PROJECT_VERSION = {PROJECT_VERSION};',
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = NO;",
        "INFOPLIST_FILE = App/VocabWallpaper/Info.plist;",
        "LD_RUNPATH_SEARCH_PATHS = (",
        "\t\"$(inherited)\",",
        "\t\"@executable_path/Frameworks\",",
        ");",
        f"MARKETING_VERSION = {MARKETING_VERSION};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {APP_BUNDLE_ID};",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "TARGETED_DEVICE_FAMILY = \"1,2\";",
    ])


def widget_target_settings():
    return "\n".join("\t\t\t\t" + line for line in [
        "CODE_SIGN_ENTITLEMENTS = Widget/VocabWidget/VocabWidget.entitlements;",
        "CODE_SIGN_STYLE = Automatic;",
        f'CURRENT_PROJECT_VERSION = {PROJECT_VERSION};',
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = NO;",
        "INFOPLIST_FILE = Widget/VocabWidget/Info.plist;",
        "LD_RUNPATH_SEARCH_PATHS = (",
        "\t\"$(inherited)\",",
        "\t\"@executable_path/Frameworks\",",
        "\t\"@executable_path/../../Frameworks\",",
        ");",
        f"MARKETING_VERSION = {MARKETING_VERSION};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {WIDGET_BUNDLE_ID};",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SKIP_INSTALL = YES;",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "TARGETED_DEVICE_FAMILY = \"1,2\";",
    ])


def scheme_xml(app_target_id):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "{APP_NAME}.app"
               BlueprintName = "{APP_NAME}"
               ReferencedContainer = "container:{APP_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <TestPlans>
      </TestPlans>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()
