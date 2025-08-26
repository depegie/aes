import argparse
import pathlib
import sys
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes

AES128_KEY_SIZE = 16
AES256_KEY_SIZE = 32
AES_BLOCK_SIZE = 16
AES_CTR_SIZE = 4

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent.as_posix()
INCLUDE_DIR = SCRIPT_DIR + '/../include/'
STIMULUS_DIR = SCRIPT_DIR + '/../stimulus/'

MODULE_TYPES = [
    'aes128_ecb_iter_behav',
    'aes128_ecb_comb_behav',
    'aes128_ecb_pipe_behav',
    'aes256_ecb_pipe_behav',
    'aes256_ctr_pipe_behav',
    'aes256_ctr_pipe_gate'
]

def aes128_ecb(vectors_num : int):
    open(STIMULUS_DIR+'pkts_in.txt', 'w').close()
    open(STIMULUS_DIR+'pkts_out.txt', 'w').close()
    
    mode = AES.MODE_ECB
    
    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES128_KEY_SIZE)
        plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
        ciphertext = AES.new(key, mode).encrypt(plaintext)

        with open(STIMULUS_DIR+'pkts_in.txt', 'a') as f:
            f.write(key.hex() + plaintext.hex() + '\n')
        
        with open(STIMULUS_DIR+'pkts_out.txt', 'a') as f:
            f.write(ciphertext.hex() + '\n')

def aes256_ecb(vectors_num : int):
    open(STIMULUS_DIR+'pkts_in.txt', 'w').close()
    open(STIMULUS_DIR+'pkts_out.txt', 'w').close()
    
    mode = AES.MODE_ECB
    
    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES256_KEY_SIZE)
        plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
        ciphertext = AES.new(key, mode).encrypt(plaintext)

        with open(STIMULUS_DIR+'pkts_in.txt', 'a') as f:
            f.write(key.hex() + plaintext.hex() + '\n')
        
        with open(STIMULUS_DIR+'pkts_out.txt', 'a') as f:
            f.write(ciphertext.hex() + '\n')

def aes256_ctr(vectors_num : int):
    open(STIMULUS_DIR+'pkts_in.txt', 'w').close()
    open(STIMULUS_DIR+'pkts_out.txt', 'w').close()

    mode = AES.MODE_CTR

    for n in range(1, vectors_num+1):
        key = get_random_bytes(AES256_KEY_SIZE)
        nonce = get_random_bytes(AES_BLOCK_SIZE-AES_CTR_SIZE)
        plaintext = get_random_bytes(n*AES_BLOCK_SIZE)
        ciphertext = AES.new(key, mode, nonce=nonce, initial_value=0).encrypt(plaintext)

        with open(STIMULUS_DIR+'pkts_in.txt', 'a') as f:
            f.write(key.hex() + nonce.hex() + '00000000' + plaintext.hex() + '\n')
        
        with open(STIMULUS_DIR+'pkts_out.txt', 'a') as f:
            f.write(ciphertext.hex() + '\n')

parser = argparse.ArgumentParser(description='AES Stimulus Generator')

parser.add_argument('-v', type=str, default=MODULE_TYPES[0], help='pass module version')
parser.add_argument('-n', type=int, default=1, help='pass number of test vectors')
parser.add_argument('--sw', type=int, default=32, help='pass S_axis.tdata width in bits')
parser.add_argument('--mw', type=int, default=32, help='pass M_axis.tdata width in bits')
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
    case 'aes128_ecb_iter_behav':
        aes128_ecb(vectors_number)
    case 'aes128_ecb_comb_behav':
        aes128_ecb(vectors_number)
    case 'aes128_ecb_pipe_behav':
        aes128_ecb(vectors_number)
    case 'aes256_ecb_pipe_behav':
        aes256_ecb(vectors_number)
    case 'aes256_ctr_pipe_behav':
        aes256_ctr(vectors_number)
    case 'aes256_ctr_pipe_gate':
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
