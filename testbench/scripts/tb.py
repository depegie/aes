import argparse
import pathlib
import sys
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
import random

AES_128_KEY_LENGTH = 16
AES_256_KEY_LENGTH = 32
AES_BLOCK_SIZE = 16
AES_CTR_SIZE = 4

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent.as_posix()
INCLUDE_DIR = SCRIPT_DIR + '/../include/'
STIMULUS_DIR = SCRIPT_DIR + '/../stimulus/'

def aes_256_cbc(vectors_num : int):
    pkts_in = open(STIMULUS_DIR+'pkts_in.txt', 'w')
    pkts_out = open(STIMULUS_DIR+'pkts_out.txt', 'w')

    mode = AES.MODE_CBC

    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES_256_KEY_LENGTH)
        iv = get_random_bytes(AES_BLOCK_SIZE)

        encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

        if encrypt:
            plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
            ciphertext = AES.new(key, mode, iv).encrypt(plaintext)
            pkts_in.write('1 ' + (key + iv + plaintext).hex() + '\n')
            pkts_out.write('1 ' + ciphertext.hex() + '\n')
        else:
            ciphertext = get_random_bytes(n*AES_BLOCK_SIZE)
            plaintext = AES.new(key, mode, iv).decrypt(ciphertext)
            pkts_in.write('0 ' + (key + iv + ciphertext).hex() + '\n')
            pkts_out.write('0 ' + plaintext.hex() + '\n')

    pkts_in.close()
    pkts_out.close()

def aes256_ctr(vectors_num : int):
    open(STIMULUS_DIR+'pkts_in.txt', 'w').close()
    open(STIMULUS_DIR+'pkts_out.txt', 'w').close()

    mode = AES.MODE_CTR

    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES_256_KEY_LENGTH)
        nonce = get_random_bytes(AES_BLOCK_SIZE-AES_CTR_SIZE)
        plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
        ciphertext = AES.new(key, mode, nonce=nonce, initial_value=0).encrypt(plaintext)

        with open(STIMULUS_DIR+'pkts_in.txt', 'a') as f:
            f.write(key.hex() + nonce.hex() + '00000000' + plaintext.hex() + '\n')
        
        with open(STIMULUS_DIR+'pkts_out.txt', 'a') as f:
            f.write(ciphertext.hex() + '\n')

parser = argparse.ArgumentParser(description='AES Stimulus Generator')

parser.add_argument('-v', type=str, default='aes256_cbc_iter', help='pass module version')
parser.add_argument('-n', type=int, default=1, help='pass number of test vectors')
parser.add_argument('--sw', type=int, default=64, help='pass S_axis.tdata width in bits')
parser.add_argument('--mw', type=int, default=64, help='pass M_axis.tdata width in bits')
parser.add_argument('--sd', type=int, default=0, help='pass driver delay in clock periods')
parser.add_argument('--md', type=int, default=0, help='pass monitor delay in clock periods')

args = parser.parse_args()

module_type = args.v
vectors_number = args.n
slave_axis_width = args.sw
master_axis_width = args.mw
slave_axis_delay = args.sd
master_axis_delay = args.md

match module_type:
    case 'aes256_cbc_iter':
        aes_256_cbc(vectors_number)
    case 'aes256_cbc_comb':
        aes_256_cbc(vectors_number)
    case 'aes256_ctr_iter':
        aes256_ctr(vectors_number)
    case 'aes256_ctr_comb':
        aes256_ctr(vectors_number)
    case 'aes256_ctr_pipe':
        aes256_ctr(vectors_number)
    case _:
        sys.exit('Invalid module type')

conf_file_content = [
    f'`define {module_type.upper()}',
    f'`define S_AXIS_WIDTH {slave_axis_width}',
    f'`define M_AXIS_WIDTH {master_axis_width}',
    f'`define S_AXIS_DELAY {slave_axis_delay}',
    f'`define M_AXIS_DELAY {master_axis_delay}'
]

with open(INCLUDE_DIR+'tb_conf.svh', 'w') as f:
    for line in conf_file_content:
        f.write(line + '\n')
