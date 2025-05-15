import Testing

@testable import Tool

#if os(macOS)

@Suite("Tool")
struct ToolTest {
  
  @Tool
  struct MyTool {
    
    func invoke(_ a: Int, b: String, `c`: Bool) {
      
    }
    
  }
  
//  @Tool
//  class MyClassTool {
//    
//    func invoke(_ a: Int, b: String, `c`: Bool) {
//      
//    }
//    
//  }
//  
//  @Tool
//  final class MyFinalClassTool {
//    
//    func invoke(_ a: Int, b: String, `c`: Bool) {
//      
//    }
//    
//  }
//  
//  @Tool
//  actor MyActorTool {
//    
//    func invoke(_ a: Int, b: String, `c`: Bool) {
//      
//    }
//    
//  }
  
  @Test
  func testExample() {
    
  }
  
  
}

#endif
