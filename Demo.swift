// Compile from terminal: swiftc Demo.swift
import Cocoa
import AppKit
import Metal
import MetalKit
import simd

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate
{
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification)
    {
        let windowMask = NSWindow.StyleMask(rawValue: (NSWindow.StyleMask.titled.rawValue | NSWindow.StyleMask.closable.rawValue))
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 1280, 720), styleMask: windowMask, backing: NSWindow.BackingStoreType.buffered, defer: true)
        window.orderFrontRegardless()
        window.title = "Metal API Demo"
        window.setFrameOrigin(NSMakePoint(100, 100))
        window.backgroundColor = NSColor.black
        window.contentViewController = ViewController()
        self.mainWindow = window
        app.activate(ignoringOtherApps: true)
    }

    func applicationWillBecomeActive(_ notification: Notification) { }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { return true }

    public class func makeMenu() -> NSMenu
    {
        let mainMenu = NSMenu()
        let mainAppMenuItem = NSMenuItem(title: "\(ProcessInfo.processInfo.processName)", action: nil, keyEquivalent: "")
        mainMenu.addItem(mainAppMenuItem)
        let appMenu = NSMenu()
        mainAppMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit \(ProcessInfo.processInfo.processName)", action: #selector(NSApplication.terminate(_:)),keyEquivalent: "q")
        return mainMenu
    }
}

class ViewController: NSViewController
{
    var metalView: MTKView?
    var metalRenderer: MetalRenderer?

    override func loadView() -> ()
    {
        self.metalView = MTKView()
        self.view = self.metalView!
        self.metalView?.frame =  NSMakeRect(0, 0, 1280, 720)
        self.metalView?.layer = CAMetalLayer()
        self.metalRenderer = MetalRenderer()
        self.metalView?.delegate = self.metalRenderer
        self.metalView?.preferredFramesPerSecond = 60
    }

    override func viewDidLoad() -> ()
    {
        super.viewDidLoad()
    }
}

class MetalRenderer: NSObject, MTKViewDelegate
{
    var device: MTLDevice?
    var positionBuffer: MTLBuffer?
    var uvBuffer: MTLBuffer?
    var renderPipeline: MTLRenderPipelineState?
    var commandQueue: MTLCommandQueue?

    let shaderSource: String =
        "using namespace metal;\n" +
        "struct Attribute\n" +
        "{\n" +
            "float4 position [[position]];\n" +
            "float2 uv;\n" +
        "};\n" +
        "vertex Attribute VSMain(constant float4 *position [[buffer(0)]], constant float2 *uv [[buffer(1)]], uint id [[vertex_id]])\n" +
        "{\n" +
            "Attribute attribute;\n" +
            "attribute.position = position[id];\n" +
            "attribute.uv = uv[id];\n" +
            "return attribute;\n" +
        "}\n" +
        "fragment float4 PSMain(Attribute attribute [[stage_in]])\n" +
        "{\n" +
            "return float4(attribute.uv, 0.0, 1.0);\n" +
        "}\n";

    override init()
    {
        super.init()
        self.device = MTLCreateSystemDefaultDevice()
        let positions: [Float] = [-1.0, -1.0, 0.0, 1.0, 1.0, -1.0, 0.0, 1.0, -1.0, 1.0, 0.0, 1.0, 1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, -1.0, 1.0, 0.0, 1.0]
        let texcoords: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
        self.positionBuffer = self.device?.makeBuffer(bytes:positions,length:(MemoryLayout<Float>.stride * positions.count),options:MTLResourceOptions.storageModeShared)
        self.uvBuffer = self.device?.makeBuffer(bytes:texcoords,length:(MemoryLayout<Float>.stride * texcoords.count),options:MTLResourceOptions.storageModeShared)
        let metalLibrary = try! self.device?.makeLibrary(source:shaderSource, options:nil)
        let vertexFunction = metalLibrary?.makeFunction(name: "VSMain")
        let fragmentFunction = metalLibrary?.makeFunction(name: "PSMain")
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        self.renderPipeline = try! self.device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        self.commandQueue = self.device?.makeCommandQueue()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) -> () { }

    public func draw(in view: MTKView) -> ()
    {
        (view.layer as! CAMetalLayer).device = self.device
        if let drawable = (view.layer as! CAMetalLayer).nextDrawable()
        {
            let frameBufferTexture = drawable.texture
            let renderPassDescriptor = MTLRenderPassDescriptor.init()
            renderPassDescriptor.colorAttachments[0].texture = frameBufferTexture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
            renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
            let commandBuffer = self.commandQueue?.makeCommandBuffer()
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            commandEncoder?.setRenderPipelineState(self.renderPipeline!)
            commandEncoder?.setVertexBuffer(self.positionBuffer!, offset: 0, index: 0)
            commandEncoder?.setVertexBuffer(self.uvBuffer!, offset: 0, index: 1)
            commandEncoder?.drawPrimitives(type:MTLPrimitiveType.triangle, vertexStart:0, vertexCount:6, instanceCount:1)
            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(NSApplication.ActivationPolicy.regular)
app.mainMenu = AppDelegate.makeMenu()
print(app.mainMenu?.items as Any)
let controller = AppDelegate()
app.delegate = controller
app.run()
