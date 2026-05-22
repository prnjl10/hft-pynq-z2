"""Read an ITCH 5.0 file, decode messages, and write each type to a CSV."""

import csv
import gzip
import os
import struct


def parse_timestamp(ts_hi, ts_lo):
    """Combine a 2-byte upper half and 4-byte lower half into a 48-bit nanosecond timestamp."""
    return (ts_hi << 32) | ts_lo


def decode_system_event(body):
    """Decode a System Event message body (12 bytes) into a dict."""
    msg_type, stock_locate, tracking_number, ts_hi, ts_lo, event_code = struct.unpack(
        ">cHHHIc", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "event_code": chr(event_code[0]),
    }


def decode_add_order(body):
    """Decode an Add Order message body (36 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number, buy_or_sell, shares, stock, price) = struct.unpack(
        ">cHHHIQcI8sI", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
        "buy_or_sell": chr(buy_or_sell[0]),
        "shares": shares,
        "stock": stock.decode().strip(),
        "price": price / 10000,
    }


def decode_add_order_MPID(body):
    """Decode an Add Order with MPID Attribution message body (40 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number, buy_or_sell, shares, stock, price, attr) = struct.unpack(
        ">cHHHIQcI8sI4s", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
        "buy_or_sell": chr(buy_or_sell[0]),
        "shares": shares,
        "stock": stock.decode().strip(),
        "price": price / 10000,
        "attr": attr.decode().strip(),
    }


def decode_order_executed(body):
    """Decode an Order Executed message body (31 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number, executed_shares, match_num) = struct.unpack(
        ">cHHHIQIQ", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
        "executed_shares": executed_shares,
        "match_num": match_num,
    }


def decode_order_cancel(body):
    """Decode an Order Cancel message body (23 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number, cancelled_shares) = struct.unpack(
        ">cHHHIQI", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
        "cancelled_shares": cancelled_shares,
    }


def decode_order_delete(body):
    """Decode an Order Delete message body (19 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number) = struct.unpack(
        ">cHHHIQ", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
    }


def decode_order_replace(body):
    """Decode an Order Replace message body (35 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     org_order_ref_number, new_order_ref_number, shares, price) = struct.unpack(
        ">cHHHIQQII", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "org_order_ref_number": org_order_ref_number,
        "new_order_ref_number": new_order_ref_number,
        "shares": shares,
        "price": price / 10000,
    }


def decode_trade(body):
    """Decode a Trade (non-cross) message body (44 bytes) into a dict."""
    (msg_type, stock_locate, tracking_number, ts_hi, ts_lo,
     order_ref_number, buy_or_sell, shares, stock, price, match_num) = struct.unpack(
        ">cHHHIQcI8sIQ", body
    )
    return {
        "type": chr(msg_type[0]),
        "stock_locate": stock_locate,
        "tracking_number": tracking_number,
        "timestamp": parse_timestamp(ts_hi, ts_lo),
        "order_ref_number": order_ref_number,
        "buy_or_sell": chr(buy_or_sell[0]),
        "shares": shares,
        "stock": stock.decode().strip(),
        "price": price / 10000,
        "match_num": match_num,
    }


# ============================================================================
# CSV setup — field order per message type
# ============================================================================

FIELDS = {
    "S": ["type", "stock_locate", "tracking_number", "timestamp", "event_code"],
    "A": ["type", "stock_locate", "tracking_number", "timestamp",
          "order_ref_number", "buy_or_sell", "shares", "stock", "price"],
    "F": ["type", "stock_locate", "tracking_number", "timestamp",
          "order_ref_number", "buy_or_sell", "shares", "stock", "price", "attr"],
    "E": ["type", "stock_locate", "tracking_number", "timestamp",
          "order_ref_number", "executed_shares", "match_num"],
    "X": ["type", "stock_locate", "tracking_number", "timestamp",
          "order_ref_number", "cancelled_shares"],
    "D": ["type", "stock_locate", "tracking_number", "timestamp", "order_ref_number"],
    "U": ["type", "stock_locate", "tracking_number", "timestamp",
          "org_order_ref_number", "new_order_ref_number", "shares", "price"],
    "P": ["type", "stock_locate", "tracking_number", "timestamp",
          "order_ref_number", "buy_or_sell", "shares", "stock", "price", "match_num"],
}


# ============================================================================
# Main loop
# ============================================================================

ITCH_FILE = "../data/20190730.BX_ITCH_50.gz"
OUTPUT_DIR = "output"
MAX_MESSAGES = 100_000

# Make sure the output folder exists
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Open one CSV writer per message type, write header
csv_files = {}
csv_writers = {}
for mtype, fields in FIELDS.items():
    f = open(f"{OUTPUT_DIR}/itch_{mtype}.csv", "w", newline="")
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    csv_files[mtype] = f
    csv_writers[mtype] = writer

counts = {}
total = 0

with gzip.open(ITCH_FILE, "rb") as f:
    while total < MAX_MESSAGES:

        # Step 1: read the 2-byte length prefix
        length_bytes = f.read(2)
        if len(length_bytes) < 2:
            break  # end of file

        # Step 2: convert to integer (big-endian)
        msg_length = int.from_bytes(length_bytes, byteorder="big")

        # Step 3: read the message body
        body = f.read(msg_length)

        # Step 4: extract the message type
        msg_type = chr(body[0])

        # Step 5: dispatch + write to CSV
        decoded = None
        if msg_type == "S":
            decoded = decode_system_event(body)
        elif msg_type == "A":
            decoded = decode_add_order(body)
        elif msg_type == "F":
            decoded = decode_add_order_MPID(body)
        elif msg_type == "E":
            decoded = decode_order_executed(body)
        elif msg_type == "X":
            decoded = decode_order_cancel(body)
        elif msg_type == "D":
            decoded = decode_order_delete(body)
        elif msg_type == "U":
            decoded = decode_order_replace(body)
        elif msg_type == "P":
            decoded = decode_trade(body)

        if decoded is not None:
            csv_writers[msg_type].writerow(decoded)

        # Tally
        counts[msg_type] = counts.get(msg_type, 0) + 1
        total += 1

# Close all CSV files
for f in csv_files.values():
    f.close()

# Report
print(f"Total messages: {total}")
print("\nMessage type breakdown:")
for msg_type in sorted(counts):
    decoded_marker = " (decoded → CSV)" if msg_type in FIELDS else ""
    print(f"  {msg_type}: {counts[msg_type]}{decoded_marker}")

print(f"\nCSV files written to: {OUTPUT_DIR}/")



