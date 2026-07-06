def normalize(phone):
    digits = "".join(filter(str.isdigit, str(phone)))
    if digits.startswith('91') and len(digits) > 10:
        digits = digits[2:]
    return f'+91{digits}'

test_cases = [
    ("9876543210", "+919876543210"),
    ("919876543210", "+919876543210"),
    ("+919876543210", "+919876543210"),
    ("91 9123456789", "+919123456789"),
    ("1234567890", "+911234567890"),
]

for inp, expected in test_cases:
    out = normalize(inp)
    status = "PASS" if out == expected else f"FAIL (got {out})"
    print(f"IN: {inp:20} | OUT: {out:20} | {status}")
