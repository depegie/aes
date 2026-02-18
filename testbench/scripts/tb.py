import argparse
import pathlib
import random
import sys
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from Crypto.Util import Counter

AES_KEY_LENGTH = 32
AES_BLOCK_SIZE = 16

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent.as_posix()
INCLUDE_DIR = SCRIPT_DIR + '/../include/'
STIMULUS_DIR = SCRIPT_DIR + '/../stimulus/'

def aes256_cbc(number:int, one_packet:bool, bad_packet:bool):
    pkts_in = open(STIMULUS_DIR+'pkts_in.txt', 'w')
    pkts_out = open(STIMULUS_DIR+'pkts_out.txt', 'w')

    mode = AES.MODE_CBC

    if one_packet or bad_packet:
        key = get_random_bytes(AES_KEY_LENGTH)
        iv = get_random_bytes(AES_BLOCK_SIZE)

        encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

        if encrypt:
            plaintext = get_random_bytes(number*AES_BLOCK_SIZE)
            ciphertext = AES.new(key, mode, iv).encrypt(plaintext)

            if bad_packet:
                ciphertext = ciphertext[:-1] + bytes([~ciphertext[-1] & 0xFF])
                
            pkts_in.write('1 ' + (key + iv + plaintext).hex() + '\n')
            pkts_out.write('1 ' + ciphertext.hex() + '\n')
        else:
            ciphertext = get_random_bytes(number*AES_BLOCK_SIZE)
            plaintext = AES.new(key, mode, iv).decrypt(ciphertext)

            if bad_packet:
                plaintext = plaintext[:-1] + bytes([~plaintext[-1] & 0xFF])

            pkts_in.write('0 ' + (key + iv + ciphertext).hex() + '\n')
            pkts_out.write('0 ' + plaintext.hex() + '\n')
    else:
        for n in range(1, number+1):
            key = get_random_bytes(AES_KEY_LENGTH)
            iv = get_random_bytes(AES_BLOCK_SIZE)

            encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

            if encrypt:
                plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
                ciphertext = AES.new(key, mode, iv).encrypt(plaintext)

                if bad_packet:
                    ciphertext = ciphertext[:-1] + bytes([~ciphertext[-1] & 0xFF])
                
                pkts_in.write('1 ' + (key + iv + plaintext).hex() + '\n')
                pkts_out.write('1 ' + ciphertext.hex() + '\n')
            else:
                ciphertext = get_random_bytes(n*AES_BLOCK_SIZE)
                plaintext = AES.new(key, mode, iv).decrypt(ciphertext)

                if bad_packet:
                    plaintext = plaintext[:-1] + bytes([~plaintext[-1] & 0xFF])

                pkts_in.write('0 ' + (key + iv + ciphertext).hex() + '\n')
                pkts_out.write('0 ' + plaintext.hex() + '\n')

    pkts_in.close()
    pkts_out.close()

def aes256_ctr(number:int, one_packet:bool, bad_packet:bool):
    pkts_in = open(STIMULUS_DIR+'pkts_in.txt', 'w')
    pkts_out = open(STIMULUS_DIR+'pkts_out.txt', 'w')

    mode = AES.MODE_CTR

    if one_packet or bad_packet:
        key = get_random_bytes(AES_KEY_LENGTH)
        counter_bytes = get_random_bytes(AES_BLOCK_SIZE)
        counter = Counter.new(128, initial_value=int.from_bytes(counter_bytes, "big"))

        encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

        if encrypt:
            plaintext = get_random_bytes(number)
            ciphertext = AES.new(key, mode, counter=counter).encrypt(plaintext)

            if bad_packet:
                ciphertext = ciphertext[:-1] + bytes([~ciphertext[-1] & 0xFF])

            pkts_in.write('1 ' + (key + counter_bytes + plaintext).hex() + '\n')
            pkts_out.write('1 ' + ciphertext.hex() + '\n')
        else:
            ciphertext = get_random_bytes(number)
            plaintext = AES.new(key, mode, counter=counter).decrypt(ciphertext)

            if bad_packet:
                plaintext = plaintext[:-1] + bytes([~plaintext[-1] & 0xFF])
            
            pkts_in.write('0 ' + (key + counter_bytes + ciphertext).hex() + '\n')
            pkts_out.write('0 ' + plaintext.hex() + '\n')

    else:
        for n in range(1, number+1):
            key = get_random_bytes(AES_KEY_LENGTH)
            counter_bytes = get_random_bytes(AES_BLOCK_SIZE)
            counter = Counter.new(128, initial_value=int.from_bytes(counter_bytes, "big"))

            encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

            if encrypt:
                plaintext = get_random_bytes(n)
                ciphertext = AES.new(key, mode, counter=counter).encrypt(plaintext)

                if bad_packet:
                    ciphertext = ciphertext[:-1] + bytes([~ciphertext[-1] & 0xFF])

                pkts_in.write('1 ' + (key + counter_bytes + plaintext).hex() + '\n')
                pkts_out.write('1 ' + ciphertext.hex() + '\n')
            else:
                ciphertext = get_random_bytes(n)
                plaintext = AES.new(key, mode, counter=counter).decrypt(ciphertext)

                if bad_packet:
                    plaintext = plaintext[:-1] + bytes([~plaintext[-1] & 0xFF])

                pkts_in.write('0 ' + (key + counter_bytes + ciphertext).hex() + '\n')
                pkts_out.write('0 ' + plaintext.hex() + '\n')

    pkts_in.close()
    pkts_out.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='AES Stimulus Generator')

    parser.add_argument('-m', type=str, default='aes_cbc_iterative', help='pass module version')
    parser.add_argument('-n', type=int, default=1, help='pass number of test vectors')
    parser.add_argument('--slave-delay', type=int, default=0, help='pass driver delay in clock periods')
    parser.add_argument('--master-delay', type=int, default=0, help='pass monitor delay in clock periods')
    parser.add_argument("--one-packet", action="store_true", help="generates single packet")
    parser.add_argument("--bad-packet", action="store_true", help="damages last byte of a packet")

    args = parser.parse_args()

    module = args.m
    number = args.n
    slave_delay = args.slave_delay
    master_delay = args.master_delay
    one_packet = args.one_packet
    bad_packet = args.bad_packet

    match module:
        case 'aes_cbc_iterative':
            aes256_cbc(number, one_packet, bad_packet)
        case 'aes_cbc_unrolled':
            aes256_cbc(number, one_packet, bad_packet)
        case 'aes_ctr_iterative':
            aes256_ctr(number, one_packet, bad_packet)
        case 'aes_ctr_unrolled':
            aes256_ctr(number, one_packet, bad_packet)
        case 'aes_ctr_pipelined':
            aes256_ctr(number, one_packet, bad_packet)
        case _:
            sys.exit('Invalid module type')

    conf_file_content = [
        f'`define {module.upper()}',
        f'`define S_AXIS_DELAY {slave_delay}',
        f'`define M_AXIS_DELAY {master_delay}'
    ]

    with open(INCLUDE_DIR+'tb_conf.svh', 'w') as f:
        for line in conf_file_content:
            f.write(line + '\n')
