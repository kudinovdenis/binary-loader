/*
* It is used for main executables to specify the location (file offset)
* of main().  If -stack_size was used at link time, the stacksize
* field will contain the stack size need for the main thread.
*/

public struct LcMain: Command {
    public let type: UInt32
    public let size: UInt32
    public let entryOffset: UInt64    /* file (__TEXT) offset of main() */
    public let stackSize: UInt64 /* if not zero, initial stack size */
}
