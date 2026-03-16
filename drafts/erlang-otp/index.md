---
title: Erlang OTP
date: 2026-03-02 15:00:00
description: Let's draw some happy little trees
slug: erlang-otp
---

The primitive of supervision is `link`s, which allow two processes to send exit signals to one one the other exits.

A supervisor is basically just a process that creates a `link` with its `worker`s, and will follow its exit strategy upon recieving the exit signal from a worker, either to restart the worker, exit other workers or exit itself.

An application is an entire supervision tree.

You can walk up an application supervision tree to get to the master supervisor (which is what Kino does)

GenServer is a convenience module to run a Process. (it starts a supervision tree?). GenServer lets you handle each message rather than write a loop function for the process (it does this with `handle_cast` functions with overridden args). `handle_call` is a message that expects a reply


Tangeants:
- Learn OTP
    - Represent supervision tree (Asterism)
        - Use Lustre
            - Learn Lustre components
                - Make a blog post about Lustre components
                    - Create a blog
                    - Implement Gleam syntax highlighting in the blog
            - Learn Clique
                - Figure out how to beautifully position nodes with X-Y coordinates
                    - [Learn some Graph theory and representation methods on Youtube](https://youtu.be/aMx9l7dtPpQ?list=PLubYOWSl9mIuJXdt_pMYoTD8QkaX9kQgO)
                    - Make a graph library in Gleam (Gaston)
                        - Figure out how to internally represent a Graph in a way that makes sense for Gleam
                        - Use snapshot testing ([Birdie](https://hexdocs.pm/birdie/))
                            - Represent a graph as a string
                                - Figure out how to center two stacked blocks of text horizontally & vertically