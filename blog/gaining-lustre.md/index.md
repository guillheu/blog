---
title: Gaining Lustre
date: 2026-02-28 13:28:00
description: Diving into Lustre's server components
slug: gaining-lustre
---

# I have a Dream...

There are so many projects I want to make, some of which absolutely require some kind of server-side... stuff.

So far I've only used Lustre for SPAs and static sites, but it's time to level up.

## The goal

The goal of this article is to write a reference I can go back to in the future to quickly and easily convert/create a full stack Lustre project.

The code snippets here are heavily inspired by [the Lustre server component basic setup example](https://github.com/lustre-labs/lustre/blob/main/examples/06-server-components/01-basic-setup/src/app.gleam).

We assume that we already have a fully working Lustre application, with its own `Msg` type, as well as an `app()` function that returns the `lustre.App` itself.

## Getting into it

So the first thing I understand is that a `component` is essentially a sub-application within a Lustre application. Client-side only, maybe it's useful to re-use a project within different pages... not really what I'm looking for, but what *is* interesting is `server_component`s. They're the same idea, except the component is fully rendered on the server.

The updates will all be sent over a WebSocket connection, which means the server needs to be configured to not only accept this WS connection but correctly configure it to serve the Lustre updates and stuff...

The client must be given a special lustre runtime via the `<lustre-server-component />` tag which will point to the server's WebSocket.

## The WebSocket

A WebSocket is a bi-directional communication between the server and the client. On the server, a WebSocket (using `mist`) can be created with 3 parameter:
- the `init` function
- the `loop` function
- the `close` function

### WS Init

For the needs of a server component, the `init` function needs the following steps:
- create our lustre component (just a Lustre `App`, but we're not running it directly)
- start the component with `lustre.start_server_component` (that will create an actor for the component)
- create a self-subject to recieve messages from the lustre component actor we created in the previous step
- register the self-subject to the component, and send that self-registration back to the component to ensure 2-way communication between the lustre component and the mist WebSocket handler
- return a tuple with the component `state` that will be maintained throughout the WebSocket connection, and a selector to the self-subject for the `mist` actor (not 100% sure what it's for, but it's there!). In our case, the state should contain a reference to the component and the self-subject. 

Minimal code would look something like this:

```gleam
type ComponentState {
  ComponentState(
    component: lustre.Runtime(my_component.Msg),
    self: Subject(server_component.ClientMessage(my_component.Msg)),
  )
}

fn init(_) -> #(
  ComponentState, 
  Option(Selector(server_component.ClientMessage(my_component.Msg)))
) {
  let my_component = my_component.app()

  let assert Ok(component) = lustre.start_server_component(my_component, Nil)

  let self = process.new_subject()
  let selector =
    process.new_selector()
    |> process.select(self)

  server_component.register_subject(self)
  |> lustre.send(to: component)

  #(ComponentState(component:, self:), Some(selector))
}
```

### WS Loop

The point of the `loop` is straight-forward: determine what to do whenever we recieve a websocket message, whether from the client, or from the server.

The message is a `mist.WebsocketMessage(server_component.ClientMessage(my_component.Msg))`, which is a bit of a mouthful. Let's take it apart:
- `mist.WebSocketMessage` -> That's the lowest level of WebSocket message, the raw message that doesn't even know we're doing anything Lustre related. Those can either be `mist.Text`, `mist.Binary`, `mist.Custom` (for server-to-client communications), `mist.Closed` or `mist.Shutdown`. The inner type defines what message would be sent for the `mist.Custom` message from the server to the client.
- `server_component.ClientMessage` -> Only relevant for server-to-client communication, this is Lustre doing its thing. This is how we embed the messages that will be sent back to the client-side of the component
- `my_component.Msg` -> Finally, the actual message of our component app. We got there.

There's a lot of boilerplate for the `loop` function:

```gleam
fn loop(
  state: ComponentState,
  message: mist.WebsocketMessage(server_component.ClientMessage(my_component.Msg)),
  connection: mist.WebsocketConnection,
) -> mist.Next(ComponentState, server_component.ClientMessage(my_component.Msg)) {

  case message {

    mist.Text(json) -> {
      case json.parse(json, server_component.runtime_message_decoder()) {
        Ok(runtime_message) -> lustre.send(state.component, runtime_message)
        Error(_) -> Nil
      }

      mist.continue(state)
    }

    mist.Binary(_) -> {
      mist.continue(state)
    }

    mist.Custom(client_message) -> {
      let json = server_component.client_message_to_json(client_message)
      let assert Ok(_) = mist.send_text_frame(connection, json.to_string(json))

      mist.continue(state)
    }

    mist.Closed | mist.Shutdown -> mist.stop()
  }
}
```

Here we can see Lustre expects us to parse & encode the messages with JSON.

### WS Close

This one is trivial, it's just a cleanup function after the connection is closed. In our case, we're just shutting down the component. Note that currently, we have one component instance per connection, but that we could maintain a single shared component for all users and not destroy it.

So here we choose to destroy the component, which means killing the actor that's handling our Lustre component behind the scenes:

```gleam
fn close(state: ComponentState) -> Nil {
  lustre.shutdown()
  |> lustre.send(to: state.component)
}
```

### Creating our WS

Finally we have our WebSocket connection ready

```gleam
fn serve_websocket(request: request.Request(mist.Connection))
  -> response.Response(mist.ResponseData) {
  mist.websocket(
    request:,
    on_init: init_counter_socket,
    handler: loop_counter_socket,
    on_close: close_counter_socket,
  )
}
```

With this, the `<lustre-server-component/>` element on the client will be able to get all the updates it needs from the server component...

... except, the client still needs the server component runtime

## The Client Runtime

The runtime is a `mjs` file already present on our system when installing Lustre. So it's just a matter of finding it and serving it on another endpoint.

For this, no need to reinvent the wheel:

```gleam
fn serve_runtime() -> response.Response(mist.ResponseData) {
  // `application` module from the `gleam_erlang` package
  let assert Ok(lustre_priv) = application.priv_directory("lustre")
  let file_path = lustre_priv <> "/static/lustre-server-component.mjs"

  case mist.send_file(file_path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", "application/javascript")
      |> response.set_body(file)

    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}
```

## The Client Body

Last but not least, our server does need to send over the client body. We can of course have a pre-generated static HTML file and just serve that, but we can also take advantage of Lustre's `element.to_document_string_tree` to generate a full HTML page.

We can even import the `view` function from our client and render it here as well.

For the sake of simplicity, here's an example where we locally render a simple Lustre client, but remember the sky is the limit with this

```gleam
fn serve_html() -> Response(ResponseData) {
  let html =
    html([attribute.lang("en")], [
      html.head([], [
        html.meta([attribute.charset("utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        html.title([], "My Cool Lustre App"),
        html.script(
          [attribute.type_("module"), attribute.src("/lustre/runtime.mjs")],
          "",
        ),
      ]),
      html.body([],
        [server_component.element([server_component.route("/ws")], [])],
      ),
    ])
    |> element.to_document_string_tree
    |> bytes_tree.from_string_tree

  response.new(200)
  |> response.set_body(mist.Bytes(html))
  |> response.set_header("content-type", "text/html")
}
```

As you can see we're:
- creating an HTML page using lustre (which contains the oh-so-important `server_component.element` with a `server_component.route("/ws")`, pointing to our websocket endpoint that we'll be creating in a minute)
- rendering it with `element.to_document_string_tree`
- including it in a `Response` which will be sent back by `mist`.

You'll notice that we're manually creating the `meta`, `title` and `script` tags, as well as styling. For larger projects, it's probably best to have a separate Lustre project for the client application, render it with `element.to_document_string`, save it to an HTML file and then just serve that HTML file statically. That lets you take advantage of the [Lustre TOML options to set all those tags and stuff on the client](https://hexdocs.pm/lustre_dev_tools/toml-reference.html), as well as tailwind styling and all that good stuff (:

## The Mist Handler Function

We now have handler functions for all the requests we're expecting:
- One for the WebSocket connections coming from the client's server component runtime
- One to serve the server component runtime
- One to serve the client HTML page

Putting it all together, we get this
```gleam
pub fn main() {
  let assert Ok(_) =
    fn(request: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(request) {
        [] -> serve_html()
        ["lustre", "runtime.mjs"] -> serve_runtime()
        ["ws"] -> serve_component(request)
        _ -> response.set_body(response.new(404), mist.Bytes(bytes_tree.new()))
      }
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(1234)
    |> mist.start

  process.sleep_forever()
}
```

With this, our `mist` server is listening in on `http://localhost:1234` and is serving the HTML on `/`, the WebSocket on `/ws` and the runtime on `/lustre/runtime.mjs`.

With that, we *should* have a working server component!