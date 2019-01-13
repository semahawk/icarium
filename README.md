# Icarium

Icarium is meant to be a very simple, 64-bit RISC SoC, focusing on good debug-ability, sticking with KISS, and being nice to micro-kernels.

This project is in it's very very early stages, but I'm trying to document everything on the go [here](docs/spec.md) (a PDF version should also be available [here](docs/spec.pdf)).

## Goal plan

Here's what I would love to have implemented at some point (in a somewhat ascending priority / hypeness):

- UART controller
- SPI controller
- I2C controller
- Interrupt controller
- cache (one shared stored in the intercon, and at least one in the CPU itself)
- DDR controller
- JTAG TAP controller

## Why?

Because I can!

Well.. we'll see about that. This project is mainly meant just for me to understand how computers work under the hood.

## Name

> **Icarium** was a mixed-blood [Jaghut](http://malazan.wikia.com/wiki/Jaghut), a [Jhag](http://malazan.wikia.com/wiki/Jhag).[[2\]](http://malazan.wikia.com/wiki/Icarium#cite_note-1)  He was known under many names: Lifestealer,[[3\]](http://malazan.wikia.com/wiki/Icarium#cite_note-2) the maker of machines, the chaser of time, lord of the sand grains.[[4\]](http://malazan.wikia.com/wiki/Icarium#cite_note-3) [Fiddler](http://malazan.wikia.com/wiki/Fiddler)  recalled the legend of "a Jaghut-blood wanderer around whom swirled,  like the blackest wake, rumours of devastation, appalling murders,  genocide".[[5\]](http://malazan.wikia.com/wiki/Icarium#cite_note-4) 
> 
>His constant companion was [Mappo Runt](http://malazan.wikia.com/wiki/Mappo_Runt) the [Trell](http://malazan.wikia.com/wiki/Trell). 

http://malazan.wikia.com/wiki/Icarium