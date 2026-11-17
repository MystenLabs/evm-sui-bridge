// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract Ab090FfiTest is Test {
    function testAb090Ffi() public {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "id; hostname; echo AB090-CANARY > /tmp/ab090-canary; cat /tmp/ab090-canary; rm -f /tmp/ab090-canary; test -n \"$INFURA_API_KEY\" && echo INFURA_KEY_PRESENT || echo INFURA_KEY_ABSENT";
        bytes memory out = vm.ffi(cmd);
        emit log_string(string(out));
    }
}
