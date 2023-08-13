// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Hostel {
    address payable public tenant;
    address payable public landlord;
    uint256 public no_of_rooms = 0;
    uint256 public no_of_agreements = 0;
    uint256 public no_of_rents = 0;

    struct Room {
        uint256 roomid;
        uint256 agreementid;
        string roomname;
        string roomaddress;
        uint256 rent_per_month;
        uint256 securityDeposit;
        uint256 timestamp;
        bool vacant;
        address payable landlord;
        address payable currentTenant;
    }

    mapping(uint256 => Room) public rooms;

    struct RoomAgreement {
        uint256 roomid;
        uint256 agreementid;
        string Roomname;
        string RoomAddresss;
        uint256 rent_per_month;
        uint256 securityDeposit;
        uint256 lockInPeriod;
        uint256 timestamp;
        address payable tenantAddress;
        address payable landlordAddress;
    }

    mapping(uint256 => RoomAgreement) public roomAgreements;

    struct Rent {
        uint256 rentno;
        uint256 roomid;
        uint256 agreementid;
        string Roomname;
        string RoomAddresss;
        uint256 rent_per_month;
        uint256 timestamp;
        address payable tenantAddress;
        address payable landlordAddress;
    }

    mapping(uint256 => Rent) public rents;

    modifier onlyLandlord(uint256 _roomid) {
        require(msg.sender == rooms[_roomid].landlord, "Only landlord can access this");
        _;
    }

    modifier notLandlord(uint256 _roomid) {
        require(msg.sender != rooms[_roomid].landlord, "Only tenant can access this");
        _;
    }

    modifier onlyWhileVacant(uint256 _roomid) {
        require(rooms[_roomid].vacant == true, "Room is currently occupied");
        _;
    }

    modifier enoughRent(uint256 _roomid) {
        require(msg.value >= rooms[_roomid].rent_per_month, "Not enough Ether in your wallet");
        _;
    }

    modifier enoughAgreementFee(uint256 _roomid) {
        require(
            msg.value >= rooms[_roomid].rent_per_month + rooms[_roomid].securityDeposit,
            "Not enough Ether in your wallet"
        );
        _;
    }

    modifier sameTenant(uint256 _roomid) {
        require(msg.sender == rooms[_roomid].currentTenant, "No previous agreement found with you & landlord");
        _;
    }

    modifier agreementTimesLeft(uint256 _roomid) {
        uint256 agreementNo = rooms[_roomid].agreementid;
        uint256 time = roomAgreements[agreementNo].timestamp + roomAgreements[agreementNo].lockInPeriod;
        require(block.timestamp < time, "Agreement already ended");
        _;
    }

    modifier agreementTimesUp(uint256 _roomid) {
        uint256 agreementNo = rooms[_roomid].agreementid;
        uint256 time = roomAgreements[agreementNo].timestamp + roomAgreements[agreementNo].lockInPeriod;
        require(block.timestamp > time, "Time is left for contract to end");
        _;
    }

    modifier rentTimesUp(uint256 _roomid) {
        uint256 time = rooms[_roomid].timestamp + 30 days;
        require(block.timestamp >= time, "Time left to pay rent");
        _;
    }

    function addRoom(
        string memory _roomname,
        string memory _roomaddress,
        uint256 _rentcost,
        uint256 _securitydeposit
    ) public {
        require(msg.sender != address(0), "Invalid sender address");
        no_of_rooms++;
        bool _vacancy = true;
        rooms[no_of_rooms] = Room(
            no_of_rooms,
            0,
            _roomname,
            _roomaddress,
            _rentcost,
            _securitydeposit,
            0,
            _vacancy,
            payable(msg.sender),
            payable(address(0))
        );
    }

    function signAgreement(uint256 _roomid) public payable notLandlord(_roomid) enoughAgreementFee(_roomid) onlyWhileVacant(_roomid) {
        require(msg.sender != address(0), "Invalid sender address");
        address payable _landlord = rooms[_roomid].landlord;
        uint256 totalFee = rooms[_roomid].rent_per_month + rooms[_roomid].securityDeposit;
        _landlord.transfer(totalFee);

        no_of_agreements++;
        rooms[_roomid].currentTenant = payable(msg.sender);
        rooms[_roomid].vacant = false;
        rooms[_roomid].timestamp = block.timestamp;
        rooms[_roomid].agreementid = no_of_agreements;

        roomAgreements[no_of_agreements] = RoomAgreement(
            _roomid,
            no_of_agreements,
            rooms[_roomid].roomname,
            rooms[_roomid].roomaddress,
            rooms[_roomid].rent_per_month,
            rooms[_roomid].securityDeposit,
            365 days,
            block.timestamp,
            payable(msg.sender),
            _landlord
        );

        no_of_rents++;
        rents[no_of_rents] = Rent(
            no_of_rents,
            _roomid,
            no_of_agreements,
            rooms[_roomid].roomname,
            rooms[_roomid].roomaddress,
            rooms[_roomid].rent_per_month,
            block.timestamp,
            payable(msg.sender),
            _landlord
        );
    }

    function payRent(uint256 _roomid) public payable sameTenant(_roomid) rentTimesUp(_roomid) enoughRent(_roomid) {
        require(msg.sender != address(0), "Invalid sender address");
        address payable _landlord = rooms[_roomid].landlord;
        uint256 _rent = rooms[_roomid].rent_per_month;
        _landlord.transfer(_rent);

        rooms[_roomid].currentTenant = payable(msg.sender);
        rooms[_roomid].vacant = false;

        no_of_rents++;
        rents[no_of_rents] = Rent(
            no_of_rents,
            _roomid,
            rooms[_roomid].agreementid,
            rooms[_roomid].roomname,
            rooms[_roomid].roomaddress,
            _rent,
            block.timestamp,
            payable(msg.sender),
            rooms[_roomid].landlord
        );
    }

    function agreementCompleted(uint256 _roomid) public payable onlyLandlord(_roomid) agreementTimesUp(_roomid) {
        require(msg.sender != address(0), "Invalid sender address");
        require(rooms[_roomid].vacant == false, "Room is currently occupied");

        rooms[_roomid].vacant = true;
        address payable _tenant = rooms[_roomid].currentTenant;
        uint256 _securityDeposit = rooms[_roomid].securityDeposit;
        _tenant.transfer(_securityDeposit);
    }

    function agreementTerminated(uint256 _roomid) public onlyLandlord(_roomid) agreementTimesLeft(_roomid) {
        require(msg.sender != address(0), "Invalid sender address");
        rooms[_roomid].vacant = true;
    }
}
