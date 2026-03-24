## How hermes-mcp Works

### Core Architecture

**hermes-mcp** implements the Model Context Protocol (MCP) in Elixir, enabling communication between AI models and your application. Here's how it works:

### 1. **Component Types**

**Tools** - Actions that can modify state:
```elixir
defmodule WaltUi.MCP.Tools.CreateNote do
  use Hermes.Server.Component, type: :tool

  schema do
    field :contact_id, {:required, :string}
    field :content, {:required, {:string, {:max, 1000}}}
  end

  def execute(params, frame) do
    # Perform action and return result
    {:reply, Response.text(Response.tool(), "Note created"), frame}
  end
end
```

**Resources** - Read-only data providers:
```elixir
defmodule WaltUi.MCP.Resources.GetContact do
  use Hermes.Server.Component, type: :resource

  def read(uri, frame) do
    # Return resource data
    {:ok, contact_data, frame}
  end
end
```

### 2. **Server Definition**

```elixir
defmodule WaltUi.MCP.Server do
  use Hermes.Server,
    name: "Walt UI CRM",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  # Register components
  component WaltUi.MCP.Tools.CreateNote
  component WaltUi.MCP.Resources.GetContact
end
```

### 3. **Message Flow**

1. **AI sends JSON-RPC request** → 
2. **Transport layer receives** → 
3. **Server routes to component** → 
4. **Component executes** → 
5. **Response sent back**

### 4. **The Frame Context**

The `frame` parameter carries:
- Connection state
- Request metadata  
- Authentication info
- Session context

This allows stateful interactions and passing auth tokens through the execution pipeline.

### 5. **Transport Options**

- **STDIO**: For CLI tools
- **SSE/WebSocket**: For web integrations
- **HTTP**: Standard REST-like access

### 6. **Integration Pattern**

```elixir
# In your application supervisor
children = [
  # ... other children
  {WaltUi.MCP.Server, transport: :stdio}
]
```

The library handles:
- JSON-RPC protocol compliance
- Error handling and retries
- Connection management
- Request/response correlation

This makes it straightforward to expose your Walt UI features (contacts, notes, tasks) to AI models through a standardized protocol.
