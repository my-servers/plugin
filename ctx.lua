function getRunCtx()
    return {
        cpuInfo = cpu.Info(),
        cpuPercent = cpu.Percent(0, false),
        memInfo = mem.VirtualMemory(),
        diskInfo = disk.IOCounters(),
        netInfo = net.IOCounters(),
    }
end
