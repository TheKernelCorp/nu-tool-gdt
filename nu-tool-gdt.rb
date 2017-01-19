require 'optparse'
require 'ostruct'

def seg_desc(x) x << 0x04 end
def seg_pres(x) x << 0x07 end
def seg_savl(x) x << 0x0C end
def seg_long(x) x << 0x0D end
def seg_size(x) x << 0x0E end
def seg_gran(x) x << 0x0F end
def seg_priv(x) (x & 0x03) << 0x05 end

def create_descriptor(base, limit, flags)
    entry = limit & 0xF0000
    entry |= ((flags & 0xFFFF) << 0x08) & 0xF0FF00
    entry |= (base >> 0x10) & 0xFF
    entry |= base & 0xFF000000
    entry <<= 32
    entry |= base << 0x10
    entry |= limit & 0xFFFF
    entry
end

$seg_code_x = 0x08
$seg_code_xa = 0x09
$seg_code_xr = 0x0A
$seg_code_xra = 0x0B
$seg_code_xc = 0x0C
$seg_code_xca = 0x0D
$seg_code_xrc = 0x0E
$seg_code_xrca = 0x0F
$seg_data_r = 0x00
$seg_data_ra = 0x01
$seg_data_rw = 0x02
$seg_data_rwa = 0x03
$seg_data_re = 0x04
$seg_data_rea = 0x05
$seg_data_rwe = 0x06
$seg_data_rwea = 0x07
$seg_tss_xa = 0x09

$options = {
    :format => :nasm
}

def wizard
    # Flag constants
    # Get the descriptor type
    print 'Descriptor type? [code | data | tss]> '
    desc_type = STDIN.gets.chomp.to_sym
    # Access lookup table
    inputs = {
        # ------------------------------------ | Execute | Read | Write | Accessed | Conforming | Expand-down |
        :code => {
            'x'    => OpenStruct.new(:desc => '| yes     |      |       |          |            |             |', :flag => $seg_code_x),
            'xa'   => OpenStruct.new(:desc => '| yes     |      |       | yes      |            |             |', :flag => $seg_code_xa),
            'xr'   => OpenStruct.new(:desc => '| yes     | yes  |       |          |            |             |', :flag => $seg_code_xr),
            'xra'  => OpenStruct.new(:desc => '| yes     | yes  |       | yes      |            |             |', :flag => $seg_code_xra),
            'xc'   => OpenStruct.new(:desc => '| yes     |      |       |          | yes        |             |', :flag => $seg_code_xc),
            'xca'  => OpenStruct.new(:desc => '| yes     |      |       | yes      | yes        |             |', :flag => $seg_code_xca),
            'xrc'  => OpenStruct.new(:desc => '| yes     | yes  |       |          | yes        |             |', :flag => $seg_code_xrc),
        },
        :data => {
            'r'    => OpenStruct.new(:desc => '|         | yes  |       |          |            |             |', :flag => $seg_data_r),
            'ra'   => OpenStruct.new(:desc => '|         | yes  |       | yes      |            |             |', :flag => $seg_data_ra),
            'rw'   => OpenStruct.new(:desc => '|         | yes  | yes   |          |            |             |', :flag => $seg_data_rw),
            'rwa'  => OpenStruct.new(:desc => '|         | yes  | yes   | yes      |            |             |', :flag => $seg_data_rwa),
            're'   => OpenStruct.new(:desc => '|         | yes  |       |          |            | yes         |', :flag => $seg_data_re),
            'rea'  => OpenStruct.new(:desc => '|         | yes  |       | yes      |            | yes         |', :flag => $seg_data_rea),
            'rwe'  => OpenStruct.new(:desc => '|         | yes  | yes   |          |            | yes         |', :flag => $seg_data_rwe),
            'rwea' => OpenStruct.new(:desc => '|         | yes  | yes   | yes      |            | yes         |', :flag => $seg_data_rwea),
        },
        :tss => {
            'xa'   => OpenStruct.new(:desc => '| yes     |      |       | yes      |            |             |', :flag => $seg_tss_xa),
        },
    }
    # Get the access flag
    puts 'Please choose the appropriate access flag:'
    puts '|------|---------|------|-------|----------|------------|-------------|'
    puts '| Flag | Execute | Read | Write | Accessed | Conforming | Expand-down |'
    puts '|------|---------|------|-------|----------|------------|-------------|'
    inputs[desc_type].each { |k, v| puts "| #{k.to_s.ljust(5)}#{v.desc}" }
    puts '|------|---------|------|-------|----------|------------|-------------|'
    print 'Flag> '
    access_flag = inputs[desc_type][STDIN.gets.chomp].flag
    # Get granularity
    puts 'Please choose the granularity:'
    puts '[0] 1 B  - 1 MB'
    puts '[1] 4 KB - 4 GB'
    print 'Granularity> '
    granularity = seg_gran(STDIN.gets.chomp.to_i)
    # Get privilege level
    puts 'Please choose the privilege level:'
    puts '[0] RING 0 (Kernel)'
    puts '[1] RING 1'
    puts '[2] RING 2'
    puts '[3] RING 3 (Usermode)'
    print 'Privilege> '
    privilege = seg_priv(STDIN.gets.chomp.to_i)
    # Get base
    print 'Base address (hex)> '
    base = STDIN.gets.chomp.to_i(16)
    # Get limit
    print 'Segment limit (hex)> '
    limit = STDIN.gets.chomp.to_i(16)
    # Construct entry
    present = seg_pres(1)
    size = seg_size(1) # 32-bit
    type = seg_desc(desc_type == :tss ? 0 : 1)
    flags = type | present | size | granularity | privilege | access_flag
    entry = create_descriptor(base, limit, flags)
    entry_hex = entry.to_s(16)
    # Generate entry name
    entry_var_name = "gdt32_#{desc_type.to_s.downcase}_pl#{privilege}"
    # Generate code
    case $options[:format]
    when :nasm
        puts "#{entry_var_name}: dq 0x#{entry_hex}"
    when :c
        puts "unsigned long long int #{entry_var_name} = 0x#{entry_hex}ULL"
    when :cr
        puts "#{entry_var_name} : UInt64 = 0x#{entry_hex}_u64"
    end
end

OptionParser.new do |opts|
    opts.banner = 'Usage: nu-tool-gdt.rb [options]'
    opts.on('-f', '--format [FORMAT]', String, 'Output format') do |v|
        sym = v.to_sym
        case sym
        when :nasm, :c, :cr
            $options[:format] = sym
        else
            puts 'Invalid output format!'
            puts 'Supported: nasm, c, cr'
        end
    end
    opts.on('-h', '--help') do
        puts opts
        exit 0
    end
end.parse!

# Always launch the wizard for now
wizard