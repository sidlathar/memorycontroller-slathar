from argparse import ArgumentParser
from random import getrandbits, sample, shuffle

def main():
  parser = ArgumentParser(
      description="Generate random read/write patterns for Memory Controller")
  parser.add_argument("N", help="Number of unique addresses", type=int,
                      default=1000)
  parser.add_argument("-b", "--bits", help="Number of DRAM address bits",
                      type=int, default=22)
  parser.add_argument("-o", "--out_file", help="Output file", default="mem.mif")
  args = parser.parse_args()

  datum_bits = 32 - args.bits
  if (datum_bits < 1):
    print("Must specify fewer than 32 address bits")
    exit()

  addr_bits = args.N.bit_length() + 1

  mif_header = (
      "DEPTH = {};\n"
      "WIDTH = 32;\n"
      "ADDRESS_RADIX = HEX;\n"
      "DATA_RADIX = HEX;\n"
      "CONTENT\nBEGIN\n\n").format(1 << addr_bits)
  datum_template = "{:x} : {:x};"

  addr_list = sample(range(1 << args.bits), args.N)
  data_list = {}
  mif_content = []
  index = 0

  # Read addresses
  for addr in addr_list:
    datum = getrandbits(datum_bits)
    mif_entry = (addr << datum_bits) | datum
    data_list[addr] = datum
    mif_content.append(datum_template.format(index, mif_entry))
    index += 1

  n_padding = (1 << (addr_bits - 1)) - index
  for _ in range(n_padding):
    mif_entry = 0
    mif_content.append(datum_template.format(index, mif_entry))
    index += 1

  # Write addresses, LSB=1
  shuffle(addr_list)
  for addr in addr_list:
    mif_entry = (addr << datum_bits) | data_list[addr]
    mif_content.append(datum_template.format(index, mif_entry))
    index += 1

  n_padding = (1 << addr_bits) - index
  for _ in range(n_padding):
    mif_entry = 0
    mif_content.append(datum_template.format(index, mif_entry))
    index += 1

  with open(args.out_file, "w") as fout:
    fout.write(mif_header + "\n".join(mif_content) + "\nEND")

if __name__ == "__main__":
  main()
