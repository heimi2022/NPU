import math


def dec_to_bf16(value):
    """
    输入: float (十进制数值)
    输出: (full_str, exp_str, man_str)
          - full_str: 17位完整二进制字符串
          - exp_str:   8位指数部分
          - man_str:   9位尾数部分
    """

    # 1. 处理 0 的特殊情况
    if value == 0.0:
        return "0" * 17, "0" * 8, "0" * 9

    # 2. 提取符号和绝对值
    sign = (value < 0)
    abs_val = abs(value)

    # 3. 计算指数 (归一化到 [1.0, 2.0))
    exp_val = 0
    if abs_val >= 1.0:
        while abs_val >= 2.0:
            abs_val /= 2.0
            exp_val += 1
    else:
        while abs_val < 1.0:
            abs_val *= 2.0
            exp_val -= 1

    # 4. 计算 Bias 后的指数 (8 bits)
    # Verilog逻辑: exp_biased = exp_val + 2
    exp_biased = (exp_val + 2) & 0xFF

    # 转为 8位 二进制字符串
    exp_str = f"{exp_biased:08b}"

    # 5. 计算尾数 (9 bits logic)
    # Verilog逻辑: fraction = abs_val (保留隐含的1), 乘以128
    man_raw = int(abs_val * 128.0) & 0xFF

    # 6. 处理尾数的补码 (Two's Complement)
    if sign:
        # 负数: 9位取反 + 1
        man_twos = ((~man_raw) & 0x1FF) + 1
        man_twos &= 0x1FF  # 确保截断在 9 bits
    else:
        # 正数
        man_twos = man_raw & 0x1FF

    # 转为 9位 二进制字符串
    man_str = f"{man_twos:09b}"

    # 7. 拼接完整字符串
    full_str = exp_str + man_str

    return full_str, exp_str, man_str


def rms_norm_exact(bin_e, bin_m):
    """
    输入:
    bin_e: 8位二进制字符串 (如 "11111111")
    bin_m: 9位二进制字符串 (如 "010000000")
    """

    # === 1. 解析二进制有符号数 (补码逻辑) ===

    # 解析 e (8 bit)
    e_int = int(bin_e, 2)
    if (e_int & (1 << 7)):  # 检查符号位 (第8位)
        e_int -= (1 << 8)
    print(f"Parsed e: {e_int}")
    # 解析 m (9 bit)
    m_raw = int(bin_m, 2)
    if (m_raw & (1 << 8)):  # 检查符号位 (第9位)
        m_raw -= (1 << 9)
    print(f"Parsed m: {m_raw}")
    # === 2. 按照指令处理 m ===
    m_val = m_raw / 512.0

    print(f"Input e: {bin_e} -> {e_int}")
    print(f"Input m: {bin_m} -> {m_raw} -> /512 = {m_val}")

    psum = m_val * (2 ** e_int)
    golden_result = 1.0 / math.sqrt(psum / 2048.0)
    print(f"Golden  : {golden_result}")

    # === 3. 线性拟合计算 ===
    # 奇 != 0.5  : -2.34375 2.578125
    # 偶           -3.3125 2.828125
    # 拟合系数
    a1, b1 = -2.34375, 2.578125
    a2, b2 = -3.3125, 2.828125

    y_approx = 0.0
    t_exponent = 0.0

    # 判断 e 的奇偶性
    if e_int % 2 != 0:
        # --- 奇数情况 ---
        print("[Mode] Odd (奇数)")
        if m_val == 0.25:
            y_approx = 0.25  # 特殊值处理
            full, exp, man = dec_to_bf16(y_approx)
            y_approx = int(man, 2)
            if (y_approx & (1 << 8)):  # 检查符号位 (第9位)
                y_approx -= (1 << 9)
            y_approx = y_approx / 512.0
            print(f"Parsed m: {y_approx}")

            t_exponent = (17 - e_int) / 2.0
        else:
            y_approx = a1 * m_val + b1
            full, exp, man = dec_to_bf16(y_approx)
            y_approx = int(man, 2)
            if (y_approx & (1 << 8)):  # 检查符号位 (第9位)
                y_approx -= (1 << 9)
            y_approx = y_approx / 512.0
            print(f"Parsed m: {y_approx}")

            t_exponent = (15 - e_int) / 2.0
    else:
        # --- 偶数情况 ---
        print("[Mode] Even (偶数)")
        y_approx = a2 * m_val + b2
        full, exp, man = dec_to_bf16(y_approx)
        y_approx = int(man, 2)
        if (y_approx & (1 << 8)):  # 检查符号位 (第9位)
            y_approx -= (1 << 9)
        y_approx = y_approx / 512.0
        print(f"Parsed m: {y_approx}")

        t_exponent = (16 - e_int) / 2.0

    # === 4. 最终结果 ===
    final_result = y_approx * (2 ** t_exponent)

    print(f"y_approx: {y_approx}")
    print(f"exponent: {t_exponent}")
    print(f"Result  : {final_result}")
    print("-" * 30)

    return final_result


# ==========================================
# 在这里填入你的二进制串进行测试
# ==========================================
if __name__ == "__main__":

    # Case 1: 你可以修改这里的字符串
    e_str = "00001011"  # e = 11
    m_str = "010000000"  # m = 128 -> 128/512 = 0.5

    rms_norm_exact(e_str, m_str)
