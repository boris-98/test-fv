localparam int ORACLE_NUM_MOVES = 42;
localparam int CP_STRIDE = 16;
localparam int NUM_CP = 4;
localparam int CP_BUDGET [0:NUM_CP-2] = '{16, 16, 10};

localparam logic [1:0] ORACLE_FR [0:ORACLE_NUM_MOVES-1] = '{
  2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd1, 2'd0, 2'd0,
  2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd0, 2'd1, 2'd1,
  2'd2, 2'd2, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd2,
  2'd0, 2'd0, 2'd1, 2'd2, 2'd2, 2'd2, 2'd0, 2'd0,
  2'd1, 2'd2, 2'd1, 2'd1, 2'd0, 2'd2, 2'd2, 2'd1,
  2'd1, 2'd0
};

localparam logic [1:0] ORACLE_TO [0:ORACLE_NUM_MOVES-1] = '{
  2'd2, 2'd1, 2'd1, 2'd0, 2'd0, 2'd2, 2'd1, 2'd1,
  2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd2, 2'd2, 2'd0,
  2'd1, 2'd1, 2'd2, 2'd2, 2'd2, 2'd0, 2'd0, 2'd1,
  2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd1, 2'd2, 2'd2,
  2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd1, 2'd0, 2'd2,
  2'd2, 2'd2
};

localparam logic [1:0] CP_ROD [0:NUM_CP-1][0:NUM_TILES-1] = '{
  '{2'd0, 2'd0, 2'd0, 2'd2, 2'd2, 2'd2},
  '{2'd1, 2'd0, 2'd0, 2'd2, 2'd0, 2'd2},
  '{2'd1, 2'd1, 2'd2, 2'd0, 2'd1, 2'd2},
  '{2'd2, 2'd2, 2'd2, 2'd0, 2'd0, 2'd0}
};

localparam logic [LEVEL_W-1:0] CP_LVL [0:NUM_CP-1][0:NUM_TILES-1] = '{
  '{0, 1, 2, 0, 1, 2},
  '{0, 1, 2, 3, 3, 2},
  '{0, 1, 2, 0, 2, 3},
  '{0, 1, 2, 0, 1, 2}
};
