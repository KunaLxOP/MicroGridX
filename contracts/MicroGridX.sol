// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MicroGridX
 * @dev Blockchain solution for managing decentralized microgrids and local energy credits
 * @author MicroGridX Team
 */
contract MicroGridX {
    
    // State variables
    address public owner;
    uint256 public totalEnergyCredits;
    uint256 public gridNodeCounter;
    
    // Structs
    struct GridNode {
        address nodeAddress;
        string nodeName;
        uint256 energyGenerated; // in kWh
        uint256 energyConsumed;  // in kWh
        uint256 creditBalance;   // Energy credits
        bool isActive;
        uint256 registrationTime;
    }
    
    struct EnergyTransaction {
        address seller;
        address buyer;
        uint256 energyAmount;    // in kWh
        uint256 creditAmount;    // Credits transferred
        uint256 timestamp;
        bool isCompleted;
    }
    
    // Mappings
    mapping(address => GridNode) public gridNodes;
    mapping(uint256 => EnergyTransaction) public energyTransactions;
    mapping(address => bool) public registeredNodes;
    
    // Arrays
    address[] public activeNodes;
    uint256[] public transactionIds;
    
    // Events
    event NodeRegistered(address indexed nodeAddress, string nodeName);
    event EnergyProduced(address indexed node, uint256 amount, uint256 creditsEarned);
    event EnergyTraded(address indexed seller, address indexed buyer, uint256 energyAmount, uint256 creditAmount);
    event CreditTransfer(address indexed from, address indexed to, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredNode() {
        require(registeredNodes[msg.sender], "Node must be registered");
        _;
    }
    
    modifier nodeExists(address _nodeAddress) {
        require(registeredNodes[_nodeAddress], "Node does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalEnergyCredits = 0;
        gridNodeCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new grid node in the microgrid network
     * @param _nodeName Name of the grid node
     */
    function registerGridNode(string memory _nodeName) external {
        require(!registeredNodes[msg.sender], "Node already registered");
        require(bytes(_nodeName).length > 0, "Node name cannot be empty");
        
        gridNodes[msg.sender] = GridNode({
            nodeAddress: msg.sender,
            nodeName: _nodeName,
            energyGenerated: 0,
            energyConsumed: 0,
            creditBalance: 0,
            isActive: true,
            registrationTime: block.timestamp
        });
        
        registeredNodes[msg.sender] = true;
        activeNodes.push(msg.sender);
        gridNodeCounter++;
        
        emit NodeRegistered(msg.sender, _nodeName);
    }
    
    /**
     * @dev Core Function 2: Record energy production and award credits
     * @param _energyAmount Amount of energy produced in kWh
     */
    function recordEnergyProduction(uint256 _energyAmount) external onlyRegisteredNode {
        require(_energyAmount > 0, "Energy amount must be greater than zero");
        require(gridNodes[msg.sender].isActive, "Node is not active");
        
        GridNode storage node = gridNodes[msg.sender];
        node.energyGenerated += _energyAmount;
        
        // Award credits: 1 kWh = 10 credits (adjustable ratio)
        uint256 creditsEarned = _energyAmount * 10;
        node.creditBalance += creditsEarned;
        totalEnergyCredits += creditsEarned;
        
        emit EnergyProduced(msg.sender, _energyAmount, creditsEarned);
    }
    
    /**
     * @dev Core Function 3: Trade energy credits between grid nodes
     * @param _buyer Address of the buying node
     * @param _energyAmount Amount of energy being traded in kWh
     */
    function tradeEnergyCredits(address _buyer, uint256 _energyAmount) external 
        onlyRegisteredNode 
        nodeExists(_buyer) 
    {
        require(_buyer != msg.sender, "Cannot trade with yourself");
        require(_energyAmount > 0, "Energy amount must be greater than zero");
        require(gridNodes[_buyer].isActive, "Buyer node is not active");
        require(gridNodes[msg.sender].isActive, "Seller node is not active");
        
        uint256 creditAmount = _energyAmount * 10; // 1 kWh = 10 credits
        require(gridNodes[msg.sender].creditBalance >= creditAmount, "Insufficient credit balance");
        
        // Transfer credits
        gridNodes[msg.sender].creditBalance -= creditAmount;
        gridNodes[_buyer].creditBalance += creditAmount;
        
        // Update energy consumption for buyer
        gridNodes[_buyer].energyConsumed += _energyAmount;
        
        // Record transaction
        uint256 transactionId = transactionIds.length;
        energyTransactions[transactionId] = EnergyTransaction({
            seller: msg.sender,
            buyer: _buyer,
            energyAmount: _energyAmount,
            creditAmount: creditAmount,
            timestamp: block.timestamp,
            isCompleted: true
        });
        transactionIds.push(transactionId);
        
        emit EnergyTraded(msg.sender, _buyer, _energyAmount, creditAmount);
        emit CreditTransfer(msg.sender, _buyer, creditAmount);
    }
    
    // Additional utility functions
    
    /**
     * @dev Get grid node information
     * @param _nodeAddress Address of the grid node
     */
    function getGridNodeInfo(address _nodeAddress) external view nodeExists(_nodeAddress) 
        returns (string memory nodeName, uint256 energyGenerated, uint256 energyConsumed, 
                uint256 creditBalance, bool isActive) 
    {
        GridNode memory node = gridNodes[_nodeAddress];
        return (node.nodeName, node.energyGenerated, node.energyConsumed, 
                node.creditBalance, node.isActive);
    }
    
    /**
     * @dev Get total number of active nodes
     */
    function getActiveNodeCount() external view returns (uint256) {
        return activeNodes.length;
    }
    
    /**
     * @dev Get transaction details
     * @param _transactionId ID of the transaction
     */
    function getTransactionDetails(uint256 _transactionId) external view 
        returns (address seller, address buyer, uint256 energyAmount, 
                uint256 creditAmount, uint256 timestamp, bool isCompleted) 
    {
        require(_transactionId < transactionIds.length, "Transaction does not exist");
        EnergyTransaction memory transaction = energyTransactions[_transactionId];
        return (transaction.seller, transaction.buyer, transaction.energyAmount, 
                transaction.creditAmount, transaction.timestamp, transaction.isCompleted);
    }
    
    /**
     * @dev Toggle node active status (only owner)
     * @param _nodeAddress Address of the node to toggle
     */
    function toggleNodeStatus(address _nodeAddress) external onlyOwner nodeExists(_nodeAddress) {
        gridNodes[_nodeAddress].isActive = !gridNodes[_nodeAddress].isActive;
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() external view returns (
        uint256 totalNodes, 
        uint256 totalCredits, 
        uint256 totalTransactions
    ) {
        return (gridNodeCounter, totalEnergyCredits, transactionIds.length);
    }
}
