#!/usr/bin/env bash

#
# NH5x 风扇控制 CLI
# Ubuntu / EC + ACPI/WMI
#

set -u

# =========================
# 基础配置
# =========================

LOG_DIR="$(dirname "$0")/logs"
LOG_FILE="$LOG_DIR/fanctl.log"

mkdir -p "$LOG_DIR"

# =========================
# 初始化
# =========================

sudo modprobe ec_sys write_support=1 >/dev/null 2>&1
sudo modprobe acpi_call >/dev/null 2>&1

# 清空 ACPI 调用状态
echo "" | sudo tee /proc/acpi/call >/dev/null

# =========================
# 日志函数
# =========================

log() {
    local msg="$1"

    echo "[$(date '+%F %T')] $msg" >> "$LOG_FILE"
}

# =========================
# EC读取
# =========================

read_ec_byte() {
    local offset=$1

    sudo dd if=/sys/kernel/debug/ec/ec0/io \
        bs=1 skip=$offset count=1 2>/dev/null | od -An -t u1
}

read_ec_word() {
    local high low

    high=$(read_ec_byte "$1")
    low=$(read_ec_byte "$2")

    high=$(echo "$high" | xargs)
    low=$(echo "$low" | xargs)

    echo $(( (high << 8) | low ))
}

# =========================
# RPM计算
# =========================

calc_rpm() {
    local raw=$1

    if [[ "$raw" -eq 0 ]]; then
        echo 0
        return
    fi

    echo $((2156220 / raw))
}

# =========================
# 获取状态
# =========================

get_cpu_temp() {
    local v
    v=$(read_ec_byte 7)
    echo "$(echo "$v" | xargs)"
}

get_cpu_rpm() {
    local raw
    raw=$(read_ec_word 208 209)
    calc_rpm "$raw"
}

get_gpu_rpm() {
    local raw
    raw=$(read_ec_word 210 211)

    if [[ "$raw" -eq 0 ]]; then
        echo 0
        return
    fi

    calc_rpm "$raw"
}

get_cpu_pwm() {
    local v
    v=$(read_ec_byte 206)
    echo "$(echo "$v" | xargs)"
}

get_gpu_pwm() {
    local v
    v=$(read_ec_byte 207)
    echo "$(echo "$v" | xargs)"
}

get_gpu_temp() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi \
            --query-gpu=temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null
    else
        echo "N/A"
    fi
}

# =========================
# 当前模式判断
# =========================

CURRENT_MODE="EC_AUTO"

detect_mode() {

    local cpu_pwm gpu_pwm

    cpu_pwm=$(get_cpu_pwm)
    gpu_pwm=$(get_gpu_pwm)

    if [[ "$cpu_pwm" -eq 255 ]] || [[ "$gpu_pwm" -eq 255 ]]; then
        CURRENT_MODE="PERFORMANCE"
    elif [[ "$cpu_pwm" -lt 120 ]] && [[ "$gpu_pwm" -lt 120 ]]; then
        CURRENT_MODE="QUIET"
    else
        CURRENT_MODE="EC_AUTO"
    fi
}

# =========================
# ACPI调用
# =========================

acpi_call() {
    local cmd="$1"

    echo "$cmd" | sudo tee /proc/acpi/call >/dev/null

    sleep 1
}

# =========================
# 模式切换
# =========================

set_auto_mode() {

    echo "" | sudo tee /proc/acpi/call >/dev/null

    CURRENT_MODE="EC_AUTO"

    log "切换模式 -> EC_AUTO"

}

set_quiet_mode() {

    acpi_call '\_SB.WMI.WMBB 0x0 0x79 0x19000000'

    CURRENT_MODE="QUIET"

    log "切换模式 -> QUIET"

}

set_balance_mode() {

    acpi_call '\_SB.WMI.WMBB 0x0 0x79 0x19000001'

    CURRENT_MODE="BALANCE"

    log "切换模式 -> BALANCE"

}

set_perf_mode() {

    acpi_call '\_SB.WMI.WMBB 0x0 0x79 0x19000002'

    CURRENT_MODE="PERFORMANCE"

    log "切换模式 -> PERFORMANCE"

}

set_game_mode() {

    acpi_call '\_SB.WMI.WMBB 0x0 0x79 0x19000003'

    CURRENT_MODE="GAME"

    log "切换模式 -> GAME"

}

# =========================
# 状态栏
# =========================

draw_status() {

    detect_mode

    local cpu_temp gpu_temp
    local cpu_rpm gpu_rpm
    local cpu_pwm gpu_pwm

    cpu_temp=$(get_cpu_temp)
    gpu_temp=$(get_gpu_temp)

    cpu_rpm=$(get_cpu_rpm)
    gpu_rpm=$(get_gpu_rpm)

    cpu_pwm=$(get_cpu_pwm)
    gpu_pwm=$(get_gpu_pwm)

    tput cup 0 0

    echo "=============================================================="
    echo " NH5x Fan Control CLI"
    echo "=============================================================="
    echo ""
    echo " 当前模式 : $CURRENT_MODE"
    echo ""
    echo " CPU 温度 : ${cpu_temp}°C"
    echo " GPU 温度 : ${gpu_temp}°C"
    echo ""
    echo " CPU 风扇 : ${cpu_rpm} RPM"
    echo " GPU 风扇 : ${gpu_rpm} RPM"
    echo ""
    echo " CPU PWM  : $cpu_pwm"
    echo " GPU PWM  : $gpu_pwm"
    echo ""
    echo "=============================================================="
    echo ""
    echo " 1) EC自动控制（推荐默认）"
    echo " 2) 静音模式"
    echo " 3) 性能模式"
    echo ""
    echo " 4) 平衡模式（隐藏功能）"
    echo " 5) 游戏模式（隐藏功能）"
    echo ""
    echo " q) 退出"
    echo ""
    echo -n "请输入选项: "
}

# =========================
# 后台刷新线程
# =========================

refresh_loop() {

    while true; do
        draw_status
        sleep 2
    done
}

# =========================
# 启动
# =========================

clear

log "程序启动"

refresh_loop &
REFRESH_PID=$!

trap 'kill $REFRESH_PID 2>/dev/null' EXIT

# =========================
# 输入循环
# =========================

while true; do

    read -r choice

    case "$choice" in

        1)
            set_auto_mode
            ;;

        2)
            set_quiet_mode
            ;;

        3)
            set_perf_mode
            ;;

        4)
            set_balance_mode
            ;;

        5)
            set_game_mode
            ;;

        q|Q)

            log "程序退出"

            clear

            exit 0
            ;;

        *)
            ;;
    esac

done
