---
title: Lustre Full Stack
date: 2026-03-08 23:00:00
description: With websockets no less!
slug: lustre-full-stack
---

# What? Why?

Sometimes you need something that's just a simple little guy, an SPA. 

Sometimes you need something that's server-rendered, and you make a server component

But what if you wanted something with real-time data transfers, but not server rendered? Maybe you want a dashboard but want it rendered on the front-end.

The natural fit for this is obviously a WebSocket!

Lustre server components use WebSockets under the hood, so, sure, we could simply re-use those. But server components are really meant to also render said component on the server. It's not just server-side data, but also server-side rendering.

So if we need something with **only** server-side data, we'll have to get our hands dirty.

## Fundamentals

The fundamental idea is to use a Javascript-compatible WebSocket client on the client (like [])