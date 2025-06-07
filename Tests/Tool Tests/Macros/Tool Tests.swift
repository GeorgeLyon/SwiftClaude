import JSONTestSupport
import Testing

@testable import Tool

#if os(macOS)

  @Tool
  struct MyNotNestedTool {
    func invoke(_ a: Int, b: String, `c`: Bool) {}
  }

  @Suite("Tool")
  struct ToolTest {

    @Tool
    struct MyTool {
      func invoke(_ a: Int, b: String, `c`: Bool) {}
    }

    enum Namespace {
      @Tool
      struct MyAbsurdlyNestedTool {
        func invoke(_ a: Int, b: String, isolation: isolated Actor, `c`: Bool) {}
      }
    }

    @Tool
    class MyClassTool {
      func invoke(_ a: Int, b: String, `c`: Bool, isolation: isolated Actor?) {}
    }

    @Tool
    final class MyFinalClassTool: Sendable {
      func invoke(_ a: Int, b: String, `c`: Bool) async {}
    }

    @Tool
    actor MyActorTool {
      func invoke(_ a: Int, b: String, `c`: Bool) {}
    }

    @Test
    func testCompilation() {
      /// These examples just need to compile
    }

  }

#endif
