set $lastcs = -1

define hook-stop
  # There doesn't seem to be a good way to detect if we're in 16- or
  # 32-bit mode, but in 32-bit mode we always run with CS == 8 in the
  # kernel and CS == 35 in user space
  x/20wx $esp
  printf "EAX:0x%08x; EBX:0x%08x; ECX:0x%08x; EDX:0x%08x; EBP:0x%08x\n", $eax, $ebx, $ecx, $edx, $ebp
  if $cs == 8 || $cs == 35
    if $lastcs != 8 && $lastcs != 35
      set architecture i386
    end
    x/5i $pc
  else
    if $lastcs == -1 || $lastcs == 8 || $lastcs == 35
      set architecture i8086
    end
    # Translate the segment:offset into a physical address
    printf "[%4x:%4x]\n=>", $cs, $eip
    x/4i $cs*16+$eip
  end
  set $lastcs = $cs
end

echo + target remote localhost:26000\n
target remote localhost:26000

echo + symbol-file kernel\n
symbol-file kernel
