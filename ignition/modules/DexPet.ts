// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DexPetModule = buildModule("DexPetModule", (m) => {
 
  const dexPet = m.contract("DexPet");

  return { dexPet };
});

export default DexPetModule;
