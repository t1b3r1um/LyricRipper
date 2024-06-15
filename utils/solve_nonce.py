import hashlib
import sys

def verify_nonce(result, target):
    for res_byte, tar_byte in zip(result, target):
        if res_byte > tar_byte:
            return False
        elif res_byte < tar_byte:
            break
    return True

def solve_challenge(prefix, target_hex):
    nonce = 0
    target = bytes.fromhex(target_hex)

    while True:
        input_str = f"{prefix}{nonce}".encode()
        hashed = hashlib.sha256(input_str).digest()

        if verify_nonce(hashed, target):
            break
        nonce += 1

    return str(nonce)

if __name__ == "__main__":
    prefix = sys.argv[1]
    target_hex = sys.argv[2]
    nonce = solve_challenge(prefix, target_hex)
    print(nonce)
    # Print the nonce for debugging
    #print(f"Nonce: {nonce}", file=sys.stderr)
