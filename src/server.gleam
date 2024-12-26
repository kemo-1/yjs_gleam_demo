import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string_tree
import mist
import simplifile
import sqlight

type PubSubMessage {
  Subscribe(client: Subject(String))
  Unsubscribe(client: Subject(String))
  Publish(String)
}

fn doc_pubsub_loop(message: PubSubMessage, clients: List(Subject(String))) {
  case message {
    Subscribe(client) -> {
      io.println("➕ Client Doc connected")
      [client, ..clients] |> actor.continue
    }
    Unsubscribe(client) -> {
      io.println("➖ Client Doc disconnected")
      clients
      |> list.filter(fn(c) { c != client })
      |> actor.continue
    }
    Publish(message) -> {
      io.println("Document: " <> message)
      clients |> list.each(process.send(_, message))
      clients |> actor.continue
    }
  }
}

fn awareness_pubsub_loop(message: PubSubMessage, clients: List(Subject(String))) {
  case message {
    Subscribe(client) -> {
      io.println("➕ Client Awareness connected")
      [client, ..clients] |> actor.continue
    }
    Unsubscribe(client) -> {
      io.println("➖ Client Awareness disconnected")
      clients
      |> list.filter(fn(c) { c != client })
      |> actor.continue
    }
    Publish(message) -> {
      io.println("Awareness: " <> message)
      clients |> list.each(process.send(_, message))
      clients |> actor.continue
    }
  }
}

fn new_response(status: Int, body: String) {
  response.new(status)
  |> response.set_body(body |> bytes_tree.from_string |> mist.Bytes)
}

pub fn main() {
  use conn <- sqlight.with_connection("file:db.db")
  let document_decoder = dynamic.tuple2(dynamic.string, dynamic.string)

  let sql =
    "create table if not exists documents (name PRIMARY KEY, value text);
    insert or ignore into documents (name, value) VALUES ('document', '');
"
  let assert Ok(Nil) = sqlight.exec(sql, conn)
  let assert Ok(awareness_pubsub) = actor.start([], awareness_pubsub_loop)

  let assert Ok(doc_pubsub) = actor.start([], doc_pubsub_loop)

  let assert Ok(_) =
    mist.new(fn(request) {
      let response = case request.method, request.path {
        http.Get, "/" -> {
          use index <- result.try(
            simplifile.read("dist/index.html")
            |> result.replace_error("Could not read index.html."),
          )
          new_response(200, index) |> Ok
        }
        http.Post, "/doc" -> {
          use request <- result.try(
            request
            |> request.set_header(
              "content-type",
              "application/x-www-form-urlencoded",
            )
            |> mist.read_body(99_999_999_999)
            |> result.replace_error("Could not read request body."),
          )
          let sql =
            "
  select name,value from documents
  where name = 'document'
  "
          let assert Ok([update]) =
            sqlight.query(sql, on: conn, with: [], expecting: document_decoder)
          let #(_, update) = update
          process.send(doc_pubsub, Publish(update))

          let message = request.body |> bit_array.base64_encode(True)
          let sql = "insert or replace into documents (name, value) values 
  ('document', '" <> message <> "' )"
          let assert Ok(Nil) = sqlight.exec(sql, conn)

          process.send(doc_pubsub, Publish(message))

          new_response(200, "Submitted: " <> message) |> Ok
        }

        http.Get, "/doc" ->
          mist.server_sent_events(
            request,
            response.new(200),
            init: fn() {
              let client = process.new_subject()

              process.send(doc_pubsub, Subscribe(client))
              let selector =
                process.new_selector()
                |> process.selecting(client, function.identity)
              let sql =
                "
  select name,value from documents
  where name = 'document'
  "
              let assert Ok([update]) =
                sqlight.query(
                  sql,
                  on: conn,
                  with: [],
                  expecting: document_decoder,
                )
              let #(_, update) = update
              process.send(doc_pubsub, Publish(update))

              actor.Ready(client, selector)
            },
            loop: fn(message, connection, client) {
              case
                mist.send_event(
                  connection,
                  message |> string_tree.from_string |> mist.event,
                )
              {
                Ok(_) -> actor.continue(client)
                Error(_) -> {
                  process.send(doc_pubsub, Unsubscribe(client))
                  actor.Stop(process.Normal)
                }
              }
            },
          )
          |> Ok

        http.Post, "/awareness" -> {
          use request <- result.try(
            request
            |> request.set_header(
              "content-type",
              "application/x-www-form-urlencoded",
            )
            |> mist.read_body(99_999_999_999)
            |> result.replace_error("Could not read request body."),
          )
          let awareness = request.body |> bit_array.base64_encode(True)

          process.send(awareness_pubsub, Publish(awareness))

          new_response(200, "Submitted: " <> awareness) |> Ok
        }

        http.Get, "/awareness" ->
          mist.server_sent_events(
            request,
            response.new(200),
            init: fn() {
              let client = process.new_subject()

              process.send(awareness_pubsub, Subscribe(client))
              let selector =
                process.new_selector()
                |> process.selecting(client, function.identity)

              actor.Ready(client, selector)
            },
            loop: fn(message, connection, client) {
              case
                mist.send_event(
                  connection,
                  message |> string_tree.from_string |> mist.event,
                )
              {
                Ok(_) -> actor.continue(client)
                Error(_) -> {
                  process.send(awareness_pubsub, Unsubscribe(client))
                  actor.Stop(process.Normal)
                }
              }
            },
          )
          |> Ok

        _, _ -> new_response(404, "Not found") |> Ok
      }

      case response {
        Ok(response) -> response
        Error(error) -> {
          io.print_error(error)
          new_response(500, "Internal Server Error")
        }
      }
    })
    |> mist.port(3000)
    |> mist.start_http_server

  process.sleep_forever()
}
