---
title: Gleam decoding
date: 2026-03-16 22:10:00
description: And why dynamic.from had to die
slug: gleam-decoding
---

I've been *attempting* to write a Yaml parser in pure Gleam. Taking inspiration from the `gleam_json` module, I was seeing some `Dynamic`s being used during parsing, which confused me. Isn't a `Dynamic` just a generic catch-all type when doing FFI? Why would it be needed?

After a while trying to make sense of it, I finally understood how to use the `stdlib`'s `dynamic` and `dynamic/decode` modules, how freaking cool they really are, and how I took a lot of their magic for granted.

## The Before Times

I also wrote [Themis](https://hexdocs.pm/themis/index.html), a Prometheus client for the Erlang target. It uses Erlang's ETS, and at the time, I was taking advantage of the `dynamic.from` function to turn those Gleam tuples into Erlang tuples.

But then, a few months later, `dynamic.from` was deprecated, then removed. I was upset! Now I had to do some Erlang FFI or something. Very angry face >:(

`dynamic.from` was a function that would take in *any* argument and turn it into a `Dynamic`. How? WHO CARES! For a variable-size tuple (my use-case) the behavior was very predictable and it worked with ETS so I didn't care further.

In fact, I didn't really know what a `Dynamic` really was. I thought it was just a practical catch-all type when doing FFI.

And... it is, but when handled with care, it becomes truly something beautiful.

## Turned Dyn' For What?

If `Dynamic` was only meant to be a catch-all type you wouldn't really need to make a module for it. First of all, a module dedicated to a catch-all type that would avoid Gleam's strong type system seemed very... counter-productive (if that's all it does). Second of all, it can trivially be replicated with 2 lines of FFI, __if all you care about is the catch-all type__.

The *real* kicker is its sister module, `dynamic/decode`. This module makes it possible to decode `Dynamic`s into whatever the decoder spits out. It's not *just* a somehow generic representation of whatever you put in, it's a special type with its own internal structure (which depends on the runtime) that the `decode` module can decode into whatever the decoder is meant to create, including custom type variables.

## String to Json to Dynamic to your custom type

A common use-case for dynamic decoders is wanting to create custom types from a simple JSON string. If you have the custom type
```gleam
type SchoolPerson {
    Student(name: String)
    Professor(name: String, subject: String)
}
```
... and the following JSON
```json
{
    "type": "professor",
    "name": "Chaos",
    "subject": "Doom and Destruction"
}
```
... You'd want to be able to create a `SchoolPerson` based on that JSON data, something like
```gleam
Professor(name: "Chaos", subject: "Doom and Destruction")
```

Now of course, you could just parse the JSON string, fetch each key yourself, check their values against what you expect, etc etc...

But why do all that yourself when the `dynamic/decode` already does that *for you*?

Using the code actions to generate the decoder from the custom type, we can feed it to the `json.parse` function and let it do its magic:

```gleam
// Code action-generated decoder
fn school_person_decoder() -> decode.Decoder(SchoolPerson) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "student" -> {
      use name <- decode.field("name", decode.string)
      decode.success(Student(name:))
    }
    "professor" -> {
      use name <- decode.field("name", decode.string)
      use subject <- decode.field("subject", decode.string)
      decode.success(Professor(name:, subject:))
    }
    _ -> decode.failure(Student(name: ""), "SchoolPerson")
  }
}

pub fn main() {
    let assert Ok(json_string) = simplifile.read("professor_chaos.json")
    let assert Ok(prof_chaos) = json.parse(json_string, school_person_decoder())
    Nil
}
```

It's in `json.parse` that a lot of `Dynamic` and `dynamic/decode` magic gets overlooked:
- the JSON string gets parsed to whatever internal JSON representation
- this internal JSON representation then gets carefully crafted into a `Dynamic` (which is what I was seeing when perusing the `gleam_json` sources)
- with the use of `decode.run`, that `Dynamic` is then turned into our custom type

Looking at this process, I understood that the `gleam_json` module doesn't need to do any `Dynamic` shenanigans to parse or write JSON, but it *does* need it to create variables from that data.

In Gleam, all of the decoding heavy lifting is being done for us by the `dynamic/decode` module, and the `Dynamic` type is how you're supposed to prepare your data before it gets ingested by `decode.run`.

## "What's the deal with dynamic.from?!"

Only looking at this closely made me realise that the `dynamic.from` served almost no purpose (and was actually counter-productive). Most of the time, it wouldn't be correctly decoded by `decode.run`, and would instead lead developpers to be confused as to why their `Dynamic`s weren't being decoded properly. It's because those `Dynamic`s weren't given deliberate structures! And the only way for a `Dynamic` to have a good internal structure is to *deliberately tell it what that structure should be*, using `dynamic.properties`, `dynamic.string`, `dynamic.int` etc...

Now I understand why the Gleam core team deemed it necessary to remove this *noob trap* of a function, and force developpers to accurately describe their data structure when creating a `Dynamic` to then properly decode them.

The only reason I could get away with using `dynamic.from` was that I just didn't need it. I wasn't decoding any data, so FFI was just the way to go.