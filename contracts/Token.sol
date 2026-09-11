pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // IERC20

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );



// owner => spender => allowance
mapping(address => mapping(address => uint256)) private allowances;
address[] private tokenHolders;

// index + 1 = number of token holders
// 0 means no token holders
mapping(address => uint256) private tokenHolderIndex;
mapping(address => uint256) private withdrawableDividends;


  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "Invalid recipient");
    require(balanceOf[msg.sender] >= value, "Insufficient balance");

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _syncTokenHolders(msg.sender);
    _syncTokenHolders(to);

    emit Transfer(msg.sender, to, value);
    return true;
    
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(to != address(0), "Invalid recipient");
    require(balanceOf[from] >= value, "Insufficient balance");
    require(allowances[from][msg.sender] >= value, "Insufficient allowance");

    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _syncTokenHolders(from);
    _syncTokenHolders(to);

    emit Transfer(from, to, value);
    return true;
    

  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "not ETH sent");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _syncTokenHolders(msg.sender);
    emit Transfer(address(0), msg.sender, msg.value);
  }

  function burn(address payable dest) external override {
       uint256 amount = balanceOf[msg.sender];

    require(amount > 0, "Nothing to burn");
    require(dest != address(0), "Invalid destination");

    // Effects first
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _syncTokenHolders(msg.sender);

    emit Transfer(msg.sender, address(0), amount);

    // Interaction last
    (bool success, ) = dest.call{value: amount}("");
    require(success, "ETH transfer failed");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return tokenHolders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= tokenHolders.length, "Invalid index");
    return tokenHolders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Empty dividend");
    require(totalSupply > 0, "No token holders");

    uint256 numHolders = tokenHolders.length;
    for (uint256 i = 0; i < numHolders; i++) {
      address holder = tokenHolders[i];
      uint256 dividend = msg.value.mul(balanceOf[holder]).div(totalSupply);
      withdrawableDividends[holder] = withdrawableDividends[holder].add(dividend);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "No dividends to withdraw");
    require(dest != address(0), "Invalid destination");

    withdrawableDividends[msg.sender] = 0;
    (bool success, ) = dest.call{value: amount}("");
    require(success, "ETH transfer failed");
  }


 function _syncTokenHolders(address holder) private {
   if (balanceOf[holder] > 0) {
    _addTokenHolder(holder);
   } else {
    _removeTokenHolder(holder);
   }
 }

 function _addTokenHolder(address holder) private {
   if (balanceOf[holder] > 0 && tokenHolderIndex[holder] == 0) {
    tokenHolders.push(holder);
    // store index + 1
    tokenHolderIndex[holder] = tokenHolders.length;
   }
 }

 function _removeTokenHolder(address holder) private {
    uint256 storedIndex = tokenHolderIndex[holder];
    if (storedIndex == 0) {
      return;
    }
    uint256 index = storedIndex - 1;
    uint256 lastIndex = tokenHolders.length - 1;
    if (index != lastIndex) {
      address lastHolder = tokenHolders[lastIndex];
      tokenHolders[index] = lastHolder;
      tokenHolderIndex[lastHolder] = index + 1;
    }
    tokenHolders.pop();
    tokenHolderIndex[holder] = 0;
 }


}
