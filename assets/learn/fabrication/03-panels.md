# Panels

A **panel** is several copies of a board, or several different boards, joined into one larger sheet and made together. The fab and the assembler handle one panel instead of many tiny boards, and you break them apart at the end.

## When to use one

- The board is **small**: fabs have a minimum size they can handle, and assembly lines have a bigger one.
- The boards are being **assembled**: machines need rails to grip and marks to line up on.
- You want **many of the same board**, and panelling them is cheaper than paying per board.

For a handful of bare boards of a normal size, you usually don't need one.

## How boards are joined

- **Mouse bites**: short tabs with a row of small holes through them, like the perforation on a stamp. They work with any board shape, but leave small bumps on the edge to sand off.
- **V-scoring**: a V-shaped groove cut into both faces, so the boards snap apart cleanly. Only straight lines running right across the panel, so it suits rectangular boards.

> Keep copper and parts back from the break line, especially with V-scoring. Snapping flexes the board, and parts right at the edge can crack.

## What else goes on the panel

- **Rails**: plain strips along the edges for the assembly machine to hold.
- **Fiducials**: small round copper marks, usually three, that the pick-and-place camera finds to line the panel up exactly.
- **Tooling holes**: holes in the rails that pin the panel in place during assembly.

In Zolt, the **Panelization** section builds the panel from your board, adds rails, fiducials and tooling holes, and writes the files for the whole panel. Check the sizes your assembler asks for before ordering.
