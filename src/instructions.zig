const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpInfo = @import("opcodes.zig").OpInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const DEBUG_CPU = @import("cpu.zig").DEBUG_CPU;


inline fn combine_bytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
    return @intCast((byte >> bit_index) & 1);
}


fn get_operand_address(cpu: *CPU, instruction: OpInfo) u16 {

    const address: u16 = switch (instruction.addressing_mode) {
        .IMMEDIATE => cpu.PC + 1,
        .ABSOLUTE => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)),
        .ABSOLUTE_X => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)) + cpu.X,
        .ABSOLUTE_Y => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)) + cpu.Y,
        .ZEROPAGE => @as(u16, cpu.bus.read(cpu.PC+1)),
        .ZEROPAGE_X => @as(u16, cpu.bus.read(cpu.PC+1)) + cpu.X,
        .ZEROPAGE_Y => @as(u16, cpu.bus.read(cpu.PC+1)) + cpu.Y,
        .RELATIVE => cpu.PC + instruction.bytes + @as(u16, cpu.bus.read(cpu.PC + 1)),
        .INDIRECT => blk: {
            const lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            const addr = cpu.bus.read(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_X => blk: {
            var lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            lookup_addr += cpu.X;
            const addr = cpu.bus.read(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_Y => blk: {
            const lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            const addr = cpu.bus.read(lookup_addr) + cpu.Y;
            break :blk addr;
        },
        .IMPLIED => undefined,
        .ACCUMULATOR => undefined,
   
    };


    return address;
    
}

const OperandInfo = struct {
    operand: u8,
    address: u16,
    page_crossed: bool,
    cycles: u3, // There can be additional cycles if a page boundary was crossed, so this parameter is used again
  
};

fn page_boundary_crossed(cpu: *CPU, addr: u16) bool {
    _ = cpu;
    _ = addr;
    return false;
}

fn get_operand(cpu: *CPU, instruction: OpInfo) OperandInfo {
    const op_info: OperandInfo = switch (instruction.addressing_mode) {
        .ACCUMULATOR => .{
            .operand = cpu.A,
            .address = undefined,
            .page_crossed = false,
            .cycles = instruction.cycles,
        },

        .IMPLIED => .{
            .operand = undefined,
            .address = undefined,
            .page_crossed = false,
            .cycles = instruction.cycles,
        },

        else => blk: {
            const address = get_operand_address(cpu, instruction);
            const operand = cpu.bus.read(address);
            const page_crossed = page_boundary_crossed(cpu, address);
            const cycles = instruction.cycles + @intFromBool(page_crossed); // If a page cross happens instructions take one cycle more to execute

            break :blk .{.operand=operand, .address=address, .page_crossed=page_crossed, .cycles=cycles};
            
        }
    };
    cpu.PC += op_info.cycles;

    if (DEBUG_CPU) {
        std.debug.print("Instruction fetched ", .{});
        instruction.print();
        std.debug.print("Operand {}", .{op_info});
    } 
   
    return op_info;
}


inline fn set_negative(cpu: *CPU, result: u8) void {
    cpu.set_status_flag(StatusFlag.NEGATIVE, get_bit_at(result, 7));
}

inline fn set_zero(cpu: *CPU, result: u8) void {
    cpu.set_status_flag(StatusFlag.ZERO, @intFromBool(result == 0));
}


// ============================= INSTRUCTION IMPLEMENTATIONS ===========================================


pub fn adc(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const operand = operand_info.operand;
    
    const a_operand = cpu.A;                                                 
    const result_carry = @addWithOverflow(cpu.A, operand + cpu.get_status_flag(StatusFlag.CARRY));
    cpu.A = result_carry[0];
    
    cpu.set_status_flag(StatusFlag.CARRY, result_carry[1]);
    
    set_zero(cpu, cpu.A);
    set_negative(cpu, cpu.A);
    const v_flag: u1  = @intCast((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80);
    cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);
}


pub fn and_fn(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    cpu.A &= operand_info.operand;
    set_negative(cpu, cpu.A);
    set_zero(cpu, cpu.A);
}


pub fn asl(cpu: *CPU, instruction: OpInfo) void {
    var result: u8 = undefined;
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => {
            result = cpu.A << 1;
            cpu.A = result;
        },
        else  => {
            const operand_info = get_operand(cpu, instruction);
            result = operand_info.operand << 1;
            cpu.bus.write(operand_info.address, result);
        }
    }

    set_negative(cpu, result);
    set_zero(cpu, result);
}

pub fn bcc(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 0) {
        cpu.PC += instruction.bytes;   
    }   
}


pub fn dummy(cpu: *CPU, instruction: OpInfo) void {
    // This function is called for every instruction that is not implemented yet
   
    std.debug.print("dummy called\n", .{});
    instruction.print();
    _ = cpu;
}