import argparse
import pathlib
import random
import sys
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from Crypto.Util import Counter

AES128_KEY_LENGTH = 16
AES256_KEY_LENGTH = 32
AES_BLOCK_SIZE = 16
AES_CTR_SIZE = 4

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent.as_posix()
INCLUDE_DIR = SCRIPT_DIR + '/../include/'
STIMULUS_DIR = SCRIPT_DIR + '/../stimulus/'

def aes256_cbc(vectors_num : int):
    pkts_in = open(STIMULUS_DIR+'pkts_in.txt', 'w')
    pkts_out = open(STIMULUS_DIR+'pkts_out.txt', 'w')

    mode = AES.MODE_CBC

    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES256_KEY_LENGTH)
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
    pkts_in = open(STIMULUS_DIR+'pkts_in.txt', 'w')
    pkts_out = open(STIMULUS_DIR+'pkts_out.txt', 'w')

    mode = AES.MODE_CTR

    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES256_KEY_LENGTH)
        counter_bytes = get_random_bytes(AES_BLOCK_SIZE)
        counter = Counter.new(128, initial_value=int.from_bytes(counter_bytes, "big"))

        encrypt = random.choices([True, False], weights=[0.5, 0.5])[0]

        if encrypt:
            plaintext = get_random_bytes(n)
            ciphertext = AES.new(key, mode, counter=counter).encrypt(plaintext)
            pkts_in.write('1 ' + (key + counter_bytes + plaintext).hex() + '\n')
            pkts_out.write('1 ' + ciphertext.hex() + '\n')
        else:
            ciphertext = get_random_bytes(n)
            plaintext = AES.new(key, mode, counter=counter).decrypt(ciphertext)
            pkts_in.write('0 ' + (key + counter_bytes + ciphertext).hex() + '\n')
            pkts_out.write('0 ' + plaintext.hex() + '\n')

    pkts_in.close()
    pkts_out.close()

parser = argparse.ArgumentParser(description='AES Stimulus Generator')

parser.add_argument('-m', type=str, default='aes256_cbc_iter', help='pass module version')
parser.add_argument('-n', type=int, default=1, help='pass number of test vectors')
parser.add_argument('--ws', type=int, default=64, help='pass S_axis.tdata width in bits')
parser.add_argument('--wm', type=int, default=64, help='pass M_axis.tdata width in bits')
parser.add_argument('--ds', type=int, default=0, help='pass driver delay in clock periods')
parser.add_argument('--dm', type=int, default=0, help='pass monitor delay in clock periods')

args = parser.parse_args()

module_type = args.m
vectors_number = args.n
slave_axis_width = args.ws
master_axis_width = args.wm
slave_axis_delay = args.ds
master_axis_delay = args.dm

match module_type:
    case 'aes256_cbc_iter':
        aes256_cbc(vectors_number)
    case 'aes256_cbc_comb':
        aes256_cbc(vectors_number)
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
