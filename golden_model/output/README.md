# Golden Reference CSV Output

This folder contains the output of the Python ITCH 5.0 golden parser
(`../itch_parser.py`). Each CSV holds the decoded fields of one message type
from the input ITCH file. These CSVs serve as the **golden reference** against
which the SystemVerilog RTL decoder (Phase 1) will be diffed for functional
verification.

## Source

Generated from the first **100,000 messages** of `20190730.BX_ITCH_50.gz`
(NASDAQ BX exchange, July 30, 2019).

## Files

| File | Message Type | Rows in this slice | Committed? |
|---|---|---|---|
| `itch_S.csv` | System Event | 2 | ✅ |
| `itch_A.csv` | Add Order | 31,572 | ❌ gitignored (~2 MB) |
| `itch_F.csv` | Add Order with MPID | 0 | ✅ |
| `itch_E.csv` | Order Executed | 79 | ✅ |
| `itch_X.csv` | Order Cancel | 36 | ✅ |
| `itch_D.csv` | Order Delete | 31,210 | ❌ gitignored (~1.5 MB) |
| `itch_U.csv` | Order Replace | 905 | ✅ |
| `itch_P.csv` | Trade (non-cross) | 63 | ✅ |

The two larger files (`itch_A.csv`, `itch_D.csv`) are gitignored to keep the
repo lean. They are fully regenerable — see below.

## Regenerating

```bash
cd ../   # i.e., into golden_model/
python itch_parser.py
```

This will overwrite all 8 CSVs based on the source data file at `../data/20190730.BX_ITCH_50.gz`. To process more than the first 100k messages, edit the `MAX_MESSAGES` constant in `itch_parser.py`.

