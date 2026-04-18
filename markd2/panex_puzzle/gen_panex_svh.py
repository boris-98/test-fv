from __future__ import annotations

import argparse # For command line
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

Move = Tuple[int, int] #(fr, to)
State = Tuple[Tuple[int, ...], Tuple[int, ...]]  # (tile_rod, tile_lvl)

@dataclass
class OracleData:
    s: int # level
    moves: List[Move] # Optimal sequence
    cp_stride: int # Where make checkpoint
    cp_budget: List[int] # Amount of moves for each segment
    cp_rod: List[List[int]] # Rod state for every checkpoint
    cp_lvl: List[List[int]] # Level state for every checkpoint

def initial_state(s: int) -> State: 
    rods = tuple([0] * s + [2] * s) 
    lvls = tuple(list(range(s)) + list(range(s)))
    return rods, lvls

def goal_state(s: int) -> State: 
    rods = tuple([2] * s + [0] * s)
    lvls = tuple(list(range(s)) + list(range(s)))
    return rods, lvls

def home_level(s: int, tile_id: int) -> int:
    return tile_id if tile_id < s else tile_id - s

def top_info(s: int, st: State) -> Tuple[List[int], List[int], List[bool]]:
    rods, lvls = st
    num_tiles = 2 * s
    max_lvl = s

    top_id = [-1, -1, -1]
    top_lvl = [-1, -1, -1]

    for tile_id in range(num_tiles):
        rod = rods[tile_id]
        lvl = lvls[tile_id]
        if lvl > top_lvl[rod]:
            top_lvl[rod] = lvl
            top_id[rod] = tile_id

    rod_full = [lvl >= max_lvl for lvl in top_lvl]
    return top_id, top_lvl, rod_full

def legal_moves(s: int, st: State) -> List[Move]:
    moves: List[Move] = []
    top_id, top_lvl, rod_full = top_info(s, st)
    max_lvl = s

    for fr in range(3):
        if top_id[fr] == -1:
            continue
        for to in range(3):
            if fr == to:
                continue
            if top_lvl[to] >= max_lvl:
                continue
            if (fr, to) in ((0, 2), (2, 0)) and rod_full[1]:
                continue

            mv_id = top_id[fr]
            base_lvl = top_lvl[to] + 1
            final_lvl = max(home_level(s, mv_id), base_lvl)
            if final_lvl <= max_lvl:
                moves.append((fr, to))
    return moves

def step(s: int, st: State, fr: int, to: int) -> State:
    rods, lvls = st
    rods_l = list(rods)
    lvls_l = list(lvls)

    top_id, top_lvl, rod_full = top_info(s, st)

    if not (0 <= fr < 3 and 0 <= to < 3 and fr != to):
        raise ValueError(f"Illegal move {fr}->{to}")
    if top_id[fr] == -1:
        raise ValueError(f"Source rod {fr} is empty")
    if top_lvl[to] >= s:
        raise ValueError(f"Destination rod {to} is full")
    if (fr, to) in ((0, 2), (2, 0)) and rod_full[1]:
        raise ValueError(f"Rule violated by move {fr}->{to}")

    mv_id = top_id[fr]
    base_lvl = top_lvl[to] + 1
    final_lvl = max(home_level(s, mv_id), base_lvl)
    if final_lvl > s:
        raise ValueError(f"Computed final level {final_lvl} exceeds MAX_LVL={s}")

    rods_l[mv_id] = to
    lvls_l[mv_id] = final_lvl
    return tuple(rods_l), tuple(lvls_l)

def solve_exact_bfs(s: int) -> List[Move]:
    start = initial_state(s)
    goal = goal_state(s)
    if start == goal:
        return []

    q = deque([start])
    parent: Dict[State, Tuple[Optional[State], Optional[Move]]] = {start: (None, None)}

    while q:
        cur = q.popleft()
        if cur == goal:
            break

        for mv in legal_moves(s, cur):
            nxt = step(s, cur, *mv)
            if nxt in parent:
                continue
            parent[nxt] = (cur, mv)
            q.append(nxt)

    if goal not in parent:
        raise RuntimeError(f"No solution found for S={s}")

    path: List[Move] = []
    cur = goal
    while True:
        prev, mv = parent[cur]
        if prev is None:
            break
        assert mv is not None
        path.append(mv)
        cur = prev
    path.reverse()
    return path


def derive_oracle_data(s: int, moves: Sequence[Move], cp_stride: int) -> OracleData:
    st = initial_state(s)
    cp_rod = [list(st[0])]
    cp_lvl = [list(st[1])]

    for idx, (fr, to) in enumerate(moves, start=1):
        st = step(s, st, fr, to)
        if idx % cp_stride == 0:
            cp_rod.append(list(st[0]))
            cp_lvl.append(list(st[1]))

    if len(moves) % cp_stride != 0:
        cp_rod.append(list(st[0]))
        cp_lvl.append(list(st[1]))

    num_segments = len(cp_rod) - 1
    cp_budget: List[int] = []
    for seg in range(num_segments):
        start = seg * cp_stride
        remaining = len(moves) - start
        cp_budget.append(cp_stride if remaining >= cp_stride else remaining)

    return OracleData(
        s=s,
        moves=list(moves),
        cp_stride=cp_stride,
        cp_budget=cp_budget,
        cp_rod=cp_rod,
        cp_lvl=cp_lvl,
    )

def fmt_move_array(name: str, values: Sequence[int]) -> str:
    lines: List[str] = []
    lines.append(f"localparam logic [1:0] {name} [0:ORACLE_NUM_MOVES-1] = '{{")
    for i in range(0, len(values), 8):
        chunk = values[i:i + 8]
        txt = ", ".join(f"2'd{v}" for v in chunk)
        trailer = "," if i + 8 < len(values) else ""
        lines.append(f"  {txt}{trailer}")
    lines.append("};")
    return "\n".join(lines)

def emit_svh(data: OracleData) -> str:
    move_count = len(data.moves)
    num_cp = len(data.cp_rod)

    fr_list = [fr for fr, _ in data.moves]
    to_list = [to for _, to in data.moves]

    out: List[str] = []
    out.append(f"localparam int ORACLE_NUM_MOVES = {move_count};")
    out.append(f"localparam int CP_STRIDE = {data.cp_stride};")
    out.append(f"localparam int NUM_CP = {num_cp};")
    out.append(
        "localparam int CP_BUDGET [0:NUM_CP-2] = '{" +
        ", ".join(str(x) for x in data.cp_budget) + "};"
    )
    out.append("")
    out.append(fmt_move_array("ORACLE_FR", fr_list))
    out.append("")
    out.append(fmt_move_array("ORACLE_TO", to_list))
    out.append("")

    out.append("localparam logic [1:0] CP_ROD [0:NUM_CP-1][0:NUM_TILES-1] = '{")
    for cp_idx, row in enumerate(data.cp_rod):
        trailer = "," if cp_idx + 1 < num_cp else ""
        row_txt = ", ".join(f"2'd{v}" for v in row)
        out.append(f"  '{{{row_txt}}}{trailer}")
    out.append("};")
    out.append("")

    out.append("localparam logic [LEVEL_W-1:0] CP_LVL [0:NUM_CP-1][0:NUM_TILES-1] = '{")
    for cp_idx, row in enumerate(data.cp_lvl):
        trailer = "," if cp_idx + 1 < num_cp else ""
        row_txt = ", ".join(str(v) for v in row)
        out.append(f"  '{{{row_txt}}}{trailer}")
    out.append("};")
    out.append("")

    return "\n".join(out)

def default_out_path(s: int) -> Path:
    return Path(f"panex_s{s}_oracle.svh")

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--s", type=int, required=True, help="Panex level S")
    ap.add_argument("--stride", type=int, default=16, help="Checkpoint stride in moves (default: 16)")
    ap.add_argument("--out", type=Path, help="Output .svh file (default: panex_s<S>_oracle.svh)")
    args = ap.parse_args()

    s = args.s
    if s < 1:
        raise SystemExit("S must be >= 1")

    moves = solve_exact_bfs(s)
    data = derive_oracle_data(s=s, moves=moves, cp_stride=args.stride)
    text = emit_svh(data)

    out_path = args.out or default_out_path(s)
    out_path.write_text(text, encoding="utf-8")

    print(f"S={s}, ORACLE_NUM_MOVES={len(moves)}, NUM_CP={len(data.cp_rod)}, CP_BUDGET={data.cp_budget}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
