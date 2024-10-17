/*
 * The build_version_command contains the min OS version on which this
 * binary was built to run for its platform.  The list of known platforms and
 * tool values following it.
 */

struct LCBuildVersionCommand: Command {
    
    enum Platform: UInt32, RawRepresentable {
        case macOS = 1
        case iOS = 2
        case tvOS = 3
        case watchOS = 4
        case bridgeOS = 5
        case maccatalyst = 6
        case iosSimulator = 7
        case tvosSimulator = 8
        case watchosSimulator = 9
        case driverkit = 10
    }
    
    let type: UInt32
    let size: UInt32
    let platform: Platform
    let minos: UInt32        /* X.Y.Z is encoded in nibbles xxxx.yy.zz */
    let sdk: UInt32        /* X.Y.Z is encoded in nibbles xxxx.yy.zz */
    let ntools: UInt32        /* number of tool entries following this */
    let tools: [BuildToolVersion]
    
    var minOsString: VersionNibble
    var sdkString: VersionNibble
    
    init(type: UInt32, size: UInt32, platform: Platform, minos: UInt32, sdk: UInt32, ntools: UInt32, tools: [BuildToolVersion]) {
        self.type = type
        self.size = size
        self.platform = platform
        self.minos = minos
        self.sdk = sdk
        self.ntools = ntools
        self.tools = tools
        self.minOsString = VersionNibble(raw: minos)
        self.sdkString = VersionNibble(raw: sdk)
    }

}

extension LCBuildVersionCommand {
    
    struct BuildToolVersion {
        
        enum Tool: UInt32, RawRepresentable {
            case clang = 1
            case swift = 2
            case ld = 3
        }
        
        let tool: Tool        /* enum for the tool */
        let version: UInt32    /* version number of the tool */
        
        var versionString: VersionNibble
        
        init(tool: Tool, version: UInt32) {
            self.tool = tool
            self.version = version
            self.versionString = VersionNibble(raw: version)
        }
    };
    
}
