// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract MultiSignedWallet {
    event Deposit(address indexed sender, uint amount, uint wallet_balance);
    event DepositWithData(address indexed sender, uint amount, uint wallet_balance, bytes data);
    event SubmitTransaction(address indexed sender, uint txid, address indexed to, uint amount, bytes data);
    event TransactionConfirmed(address indexed sender, uint txid);
    event TransactionExecuted(address indexed sender, address indexed recepient, uint amount, uint txid);
    event TransactionDeleted(address indexed sender, uint txid, uint amount);

    address[] public owners;

    uint public numConfirmationsRequired;
    mapping(address => bool) isOwner;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;
    
    struct Transaction {
        address to;
        uint amount;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    
    modifier OnlyOwner() {
       require(isOwner[msg.sender], "not Owner");

       _; 
    }

    modifier txExists(uint _index) {
        require(_index < transactions.length, "txid does not exist");
 
        _; 
     }

    modifier notConfirmed(uint _index) {
        require(!isConfirmed[_index][msg.sender], "tx already confirmed");
 
        _; 
     }

    modifier notExecuted(uint _index) {
        require(!transactions[_index].executed, "tx already executed!");
 
        _; 
    }

    // To accept funds from external contract.
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    //  To receive the funds with msg.data
    fallback() external payable {
        emit DepositWithData(msg.sender, msg.value, address(this).balance, msg.data);
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) payable {
        require(_owners.length > 0, "Owner Required");
        require(
            _numConfirmationsRequired > 0 && _owners.length >= _numConfirmationsRequired,
             "invalid number of required confirmations");

        for(uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(!isOwner[owner], "Owner already exists" );
            require(owner != address(0), "Invalid Owner");

            isOwner[owner] = true;
            owners.push(owner);

        } 
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function getData() public view returns (bytes memory) {
        return abi.encodeWithSignature(Strings.toString(transactions.length));
    }

    function submitTransaction(address _to, uint _amount, bytes memory _data) public OnlyOwner {
        uint index = transactions.length;
        
        transactions.push(
            Transaction({
                to:         _to,
                amount:     _amount,
                data:       _data,
                executed:   false,
                numConfirmations: 0
            })
        );
        emit SubmitTransaction(msg.sender, index, _to, _amount, _data);
    }

    function confirmTransaction(uint _txid) public OnlyOwner txExists(_txid) notConfirmed(_txid) {
        Transaction storage transaction = transactions[_txid];

        transaction.numConfirmations += 1;
        isConfirmed[_txid][msg.sender] = true;

        emit TransactionConfirmed(msg.sender, _txid);
    }

    function removeTransaction(uint _txid) public OnlyOwner txExists(_txid) {
        
        require(!transactions[_txid].executed, "executed transaction can not deleted");
        uint amount = transactions[_txid].amount;
        transactions[_txid] = transactions[transactions.length - 1];

        for (uint i = _txid; i < transactions.length - 1; i++) {
            transactions[i] = transactions[i + 1];
        }
        
        transactions.pop();

        emit TransactionDeleted(msg.sender, _txid, amount);
    }

    function executeTransaction(uint _txid) public OnlyOwner txExists(_txid) notExecuted(_txid) {
        Transaction storage transaction = transactions[_txid];

        require(transaction.numConfirmations >= numConfirmationsRequired, "low confirmation, cannot execute tx!");
        // value in wei - sending funds
        (bool sent, ) = transaction.to.call { value: transaction.amount } (transaction.data);

        require(sent, "Transaction is failed!");
        transaction.executed = true;

        emit TransactionExecuted(msg.sender, transaction.to, transaction.amount, _txid);
    }
}

contract CryptoPay {
    event withdraw(address indexed sender, address indexed receiver, uint amount);

    // constructor()public payable {}

    function send( address payable _to) public payable  {
        require( address(msg.sender).balance >= msg.value, "In-sufficient Balance!" );

        (bool sent,) = _to.call{value: msg.value} ("");
        
        require(sent, "Failed Transaction!");

       emit withdraw(msg.sender, _to, msg.value);
    }
}


