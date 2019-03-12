var Sequencer = artifacts.require ("./Sequencer.sol");

module.exports = function(deployer) {
  deployer.deploy(Sequencer);
}