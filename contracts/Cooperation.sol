pragma solidity ^0.6.0;

import "./SafeMath.sol";

contract Cooperation {
    using SafeMath for uint256;

    struct Cooperative {
        uint256 cooperativeId;
        string inn;
        uint256 limit;
        uint256 totalSupply;
        bool status;
    }

    struct Program {
        uint256 programId;
        uint256 cooperativeId;
        uint256 limit;
        uint256 totalSupply;
        uint256 minShare;
        bool base;
        bool status;
        string info;
    }

    struct Deal {
        uint256 dealId;
        address owner;
        uint256 ownerId;
        uint256 programId;
        address counterparty;
        uint256 counterpartyId;
        uint256 dealIdToClose;
        uint256 summary;
        uint8 status;
        bool out;
        string info;
    }

    struct Shareholder {
        uint256 shareholderId;
        address addr;
        uint256 balance;
        mapping(uint256 => uint8) levels;
        mapping(uint256 => uint256) balances;
    }

    Cooperative[] public cooperatives;
    Program[] public programs;
    Deal[] public deals;
    Shareholder[] public shareholders;

    string public currency;
    uint256 public limit;
    uint256 public totalSupply;
    bool public status;

    mapping (address => bool) public admins;
    mapping (address => uint256) addresses;
    mapping (uint256 => uint256[]) public programs4cooperative;
    mapping (uint256 => uint256[]) public deals4program;

    event ChangeAdmin(address indexed addr, bool status, uint256 indexed timestamp);
    event Opened(uint256 indexed timestamp);
    event Closed(uint256 indexed timestamp);
    event OpenedCooperative(uint256 indexed id, uint256 indexed timestamp);
    event ClosedCooperative(uint256 indexed id, uint256 indexed timestamp);
    event OpenedProgram(uint256 indexed id, uint256 indexed timestamp);
    event ClosedProgram(uint256 indexed id, uint256 indexed timestamp);
    event AddDeal(uint256 indexed id, uint256 indexed programId, uint256 indexed timestamp);
    event AcceptDeal(uint256 indexed id, uint256 indexed timestamp);
    event CancelDeal(uint256 indexed id, uint256 indexed timestamp);
    event ChangeShareholder(uint256 indexed id, uint256 indexed cooperativeId, uint8 level, uint256 indexed timestamp);
    event ChangeAddress(uint256 indexed id, address indexed addr, uint256 indexed timestamp);

    constructor
    (
        string memory _currency,
        uint256 _limit
    )
    public
    {
        currency = _currency;
        limit = _limit;
        totalSupply = 0;
        status = true;

        shareholders.push(Shareholder({
            shareholderId: 0,
            addr: msg.sender,
            balance: 0
        }));

        addresses[msg.sender] = 1;
        admins[msg.sender] = true;

        emit ChangeAddress(0, msg.sender, now);
        emit ChangeAdmin(msg.sender, true, now);
        emit Opened(now);
    }

    modifier active()
    {
        require(status, "System is stopped");
        _;
    }

    modifier activeCooperative
    (
        uint256 id
    )
    {
        require(cooperatives[id].status, "Cooperative is stopped");
        _;
    }

    modifier activeProgram
    (
        uint256 id
    )
    {
        require(programs[id].status, "Program is stopped");
        _;
    }

    modifier isAdmin()
    {
        require(admins[msg.sender], "Address isn't Admin");
        _;
    }

    modifier isCoopChairman
    (
        uint256 cooperativeId
    )
    {
        require(addresses[msg.sender] != 0, "Unknown address");
        require(shareholders[addresses[msg.sender].sub(1)].levels[cooperativeId] == 1, "Address isn't chairman of cooperative");
        _;
    }

    modifier isCoopChairmanOrAdministrator
    (
        uint256 cooperativeId
    )
    {
        require(addresses[msg.sender] != 0, "Unknown address");
        require(shareholders[addresses[msg.sender].sub(1)].levels[cooperativeId] == 1 || shareholders[addresses[msg.sender].sub(1)].levels[cooperativeId] == 2, "Address isn't chairman or administrator of cooperative");
        _;
    }

    modifier isShareHolder
    (
        uint256 cooperativeId
    )
    {
        require(addresses[msg.sender] != 0, "Unknown address");
        require(shareholders[addresses[msg.sender].sub(1)].levels[cooperativeId] > 0, "Address isn't shareholder");
        _;
    }

    function balances
    (
        address _address
    )
    public view
    returns (uint256)
    {
        if (addresses[_address] == 0) {
            return(0);
        }
        else {
            return(shareholders[addresses[_address].sub(1)].balance);
        }
    }

    function programBalances
    (
        address _address,
        uint256 _programId
    )
    public view
    returns (uint256)
    {
        if (addresses[_address] == 0) {
            return(0);
        }
        else {
            return(shareholders[addresses[_address].sub(1)].balances[_programId]);
        }
    }

    function shareholder
    (
        address _address
    )
    public view
    returns (uint256)
    {
        require(addresses[_address] != 0, "Unknown address");

        return(addresses[_address].sub(1));
    }

    function level
    (
        address _address,
        uint256 _cooperativeId
    )
    public view
    returns (uint256)
    {
        if (addresses[_address] == 0) {
            return(0);
        }
        else {
            return(shareholders[addresses[_address].sub(1)].levels[_cooperativeId]);
        }
    }

    function changeAdmin
    (
        address _address,
        bool _status
    )
    public
    isAdmin
    {
        require(admins[_address] != _status, "Admin is already in this status");

        admins[_address] = _status;

        if (addresses[_address] == 0) {
            uint256 shareholderId = shareholders.length;

            shareholders.push(Shareholder({
                shareholderId: shareholderId,
                addr: _address,
                balance: 0
            }));

            addresses[_address] = shareholderId.add(1);

            emit ChangeAddress(shareholderId, _address, now);
        }

        emit ChangeAdmin(_address, _status, now);
    }

    function changeStatus
    (
        bool _status
    )
    public
    isAdmin
    {
        require(status != _status, "Contract is already in this status");

        status = _status;

        if (_status) {
            emit Opened(now);
        }
        else {
            emit Closed(now);
        }
    }

    function addCooperative
    (
        string memory _inn,
        uint256 _limit,
        address _chairman
    )
    public
    active isAdmin
    returns
    (
        uint256 cooperativeId,
        uint256 shareholderId
    )
    {
        require(_limit <= limit, "Limit exceeded");

        cooperativeId = cooperatives.length;

        cooperatives.push(Cooperative({
            cooperativeId: cooperativeId,
            inn: _inn,
            limit: _limit,
            totalSupply: 0,
            status: true
        }));

        shareholderId = _addShareholder(_chairman, cooperativeId, 1);

        emit OpenedCooperative(cooperativeId, now);
    }

    function changeStatusCooperative
    (
        uint256 _cooperativeId,
        bool _status
    )
    public
    active isCoopChairman(_cooperativeId)
    {
        require(cooperatives[_cooperativeId].status != _status, "Cooperative is already in this status");

        cooperatives[_cooperativeId].status = _status;

        if (_status) {
            emit OpenedCooperative(_cooperativeId, now);
        }
        else {
            emit ClosedCooperative(_cooperativeId, now);
        }
    }

    function addProgram
    (
        uint256 _cooperativeId,
        uint256 _limit,
        uint256 _minShare,
        string memory _info,
        bool _base
    )
    public
    active activeCooperative(_cooperativeId) isCoopChairman(_cooperativeId)
    returns (uint256 programId)
    {
        require(_limit <= cooperatives[_cooperativeId].limit, "Limit exceeded");

        programId = programs.length;

        programs.push(Program({
            programId: programId,
            cooperativeId: _cooperativeId,
            limit: _limit,
            totalSupply: 0,
            minShare: _minShare,
            base: _base,
            status: true,
            info: _info
        }));

        programs4cooperative[_cooperativeId].push(programId);

        emit OpenedProgram(programId, now);
    }

    function changeStatusProgram
    (
        uint256 _programId,
        bool _status
    )
    public
    active activeCooperative(programs[_programId].cooperativeId) isCoopChairman(programs[_programId].cooperativeId)
    {
        require(programs[_programId].status != _status, "Program is already in this status");

        programs[_programId].status = _status;

        if (_status) {
            emit OpenedProgram(_programId, now);
        }
        else {
            emit ClosedProgram(_programId, now);
        }
    }

    function addShareholder
    (
        address _address,
        uint256 _cooperativeId,
        uint8 _level
    )
    public
    active activeCooperative(_cooperativeId) isCoopChairmanOrAdministrator(_cooperativeId)
    returns (uint256 shareholderId)
    {
        require(_level != 0 && (level(msg.sender, _cooperativeId) == 1 || _level > 2), "Wrong level");

        shareholderId = _addShareholder(_address, _cooperativeId, _level);
    }

    function changeShareholder
    (
        uint256 _shareholderId,
        uint256 _cooperativeId,
        uint8 _level
    )
    public
    active activeCooperative(_cooperativeId) isCoopChairmanOrAdministrator(_cooperativeId)
    {
        uint8 currentLevel = shareholders[_shareholderId].levels[_cooperativeId];
        require(level(msg.sender, _cooperativeId) == 1 || ((_level > 2 || _level == 0) && (currentLevel > 2 || currentLevel == 0)), "Wrong level");
        require(currentLevel != _level, "Shareholder already have this level");

        shareholders[_shareholderId].levels[_cooperativeId] = _level;

        emit ChangeShareholder(_shareholderId, _cooperativeId, _level, now);
    }

    function replaceShareholder
    (
        uint256 _shareholderId,
        address _newAddress
    )
    public
    active isAdmin
    {
        require(addresses[_newAddress] == 0, "Address is already in system");
        require(_shareholderId < shareholders.length, "Wrong shareholder ID");

        addresses[_newAddress] = _shareholderId.add(1);
        addresses[shareholders[_shareholderId].addr] = 0;
        shareholders[_shareholderId].addr = _newAddress;

        emit ChangeAddress(_shareholderId, _newAddress, now);
    }

    function addDeal
    (
        uint256 _programId,
        bool _out,
        uint256 _summary,
        address _counterparty,
        uint256 _dealIdToClose,
        string memory _info
    )
    public
    active activeCooperative(programs[_programId].cooperativeId) activeProgram(_programId) isShareHolder(programs[_programId].cooperativeId)
    returns (uint256 dealId)
    {
        require(programs[_programId].minShare <= _summary, "Share less than the minimum");
        require(!_out || programBalances(msg.sender, _programId) >= _summary, "Not enough fund");
        require(_out || (totalSupply.add(_summary) <= limit && programs[_programId].totalSupply.add(_summary) <= programs[_programId].limit && cooperatives[programs[_programId].cooperativeId].totalSupply.add(_summary) <= cooperatives[programs[_programId].cooperativeId].limit), "Limit exceeded");

        uint256 ownerId = shareholder(msg.sender);
        uint256 counterpartyId = 0;
        require(_summary > 0, "Invalid input parameters");
        if (_dealIdToClose != 0) {
            require(deals[_dealIdToClose].summary == _summary && deals[_dealIdToClose].programId == _programId && _out && deals[_dealIdToClose].dealIdToClose == 0 && deals[_dealIdToClose].counterparty == msg.sender && _counterparty == address(0), "Invalid input parameters");
            counterpartyId = shareholder(_counterparty);
        }

        dealId = deals.length;

        deals.push(Deal({
            dealId: dealId,
            owner: msg.sender,
            ownerId: ownerId,
            programId: _programId,
            counterparty: _counterparty,
            counterpartyId: counterpartyId,
            dealIdToClose: _dealIdToClose,
            summary: _summary,
            status: 1,
            out: _out,
            info: _info
        }));

        deals4program[_programId].push(dealId);

        if (_dealIdToClose != 0) {
            deals[_dealIdToClose].dealIdToClose = dealId;
        }

        emit AddDeal(dealId, _programId, now);
    }

    function changeStatusDeal
    (
        uint256 _dealId,
        uint8 _status
    )
    public
    active activeCooperative(programs[deals[_dealId].programId].cooperativeId) activeProgram(deals[_dealId].programId) isCoopChairman(programs[deals[_dealId].programId].cooperativeId)
    {
        Deal storage d = deals[_dealId];
        Program storage p = programs[d.programId];
        Cooperative storage c = cooperatives[p.cooperativeId];
        Shareholder storage s = shareholders[d.ownerId];
        Shareholder storage s_close = shareholders[d.counterpartyId];

        require(_status == 2 || _status == 3, "Wrong status");
        require(_status != d.status, "Deal is already in this status");
        require(_status == 3 || d.out || (totalSupply.add(d.summary) <= limit && p.totalSupply.add(d.summary) <= p.limit && c.totalSupply.add(d.summary) <= c.limit), "Limit exceeded");
        require(_status == 3 || (d.counterparty == address(0) && d.dealIdToClose == 0) || d.dealIdToClose != 0, "Deal is not confirmed");

        d.status = _status;
        if (d.dealIdToClose != 0) {
            deals[d.dealIdToClose].status = _status;
        }

        if (_status == 2) {
            if (d.out) {
                s.balances[d.programId] = s.balances[d.programId].sub(d.summary);
                s.balance = s.balance.sub(d.summary);

                if (d.dealIdToClose == 0) {
                    totalSupply = totalSupply.sub(d.summary);
                    p.totalSupply = p.totalSupply.sub(d.summary);
                    c.totalSupply = c.totalSupply.sub(d.summary);
                }
                else {
                    s_close.balances[d.programId] = s_close.balances[d.programId].add(d.summary);
                    s_close.balance = s_close.balance.add(d.summary);
                    emit AcceptDeal(d.dealIdToClose, now);
                }
            }
            else {
                s.balances[d.programId] = s.balances[d.programId].add(d.summary);
                s.balance = s.balance.add(d.summary);

                if (d.dealIdToClose == 0) {
                    totalSupply = totalSupply.add(d.summary);
                    p.totalSupply = p.totalSupply.add(d.summary);
                    c.totalSupply = c.totalSupply.add(d.summary);
                }
                else {
                    s_close.balances[d.programId] = s_close.balances[d.programId].sub(d.summary);
                    s_close.balance = s_close.balance.sub(d.summary);
                    emit AcceptDeal(d.dealIdToClose, now);
                }
            }
            emit AcceptDeal(_dealId, now);
        }
        else {
            emit CancelDeal(_dealId, now);
            if (d.dealIdToClose != 0) {
                emit CancelDeal(d.dealIdToClose, now);
            }
        }
    }

    function _addShareholder
    (
        address _address,
        uint256 _cooperativeId,
        uint8 _level
    )
    internal
    returns (uint256 shareholderId)
    {
        shareholderId = addresses[_address];

        if (shareholderId == 0) {
            shareholderId = shareholders.length;

            shareholders.push(Shareholder({
                shareholderId: shareholderId,
                addr: _address,
                balance: 0
            }));

            shareholders[shareholderId].levels[_cooperativeId] = _level;
            addresses[_address] = shareholderId.add(1);

            emit ChangeAddress(shareholderId, _address, now);
        }
        else {
            shareholderId = shareholderId.sub(1);
            require(shareholders[shareholderId].levels[_cooperativeId] == 0, "Shareholder is already in cooperative");

            shareholders[shareholderId].levels[_cooperativeId] = _level;
        }

        emit ChangeShareholder(shareholderId, _cooperativeId, _level, now);
    }
}