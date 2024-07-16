// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "src/utils/SVG.sol";
import {JSON} from "src/utils/JSON.sol";
import {ITokenCurve} from "src/interface/ITokenCurve.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";
import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {ITokenMinter, TokenTitle, TokenSource, TokenBuilder} from "src/interface/ITokenMinter.sol";

/// @title
/// @notice
contract TokenUriBuilder {
    /// -----------------------------------------------------------------------
    /// Builder Router
    /// -----------------------------------------------------------------------

    function build(
        uint256 builderId,
        TokenTitle memory title,
        TokenSource memory source
    ) external view returns (string memory) {
        if (builderId == 1) {
            // List owner token.
            return qsForCroissant(title, source);
        } else if (builderId == 2) {
            // List owner token.
            return qsForCoffee(title, source);
        } else if (builderId == 3) {
            // List owner token.
            return qsForPitcherDelivry(title, source);
        } else if (builderId == 4) {
            // List user token.
            return deliveryRecord(title, source);
        } else {
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    ///  Getter
    /// -----------------------------------------------------------------------

    function generateSvg(
        uint256 builderId,
        address user,
        address bulletin,
        uint256 listId,
        address logger
    ) public view returns (string memory) {
        if (builderId == 1) {
            // List owner token.
            return generateSvgForQsForCroissant(bulletin, listId, logger);
        } else if (builderId == 2) {
            // List owner token.
            return generateSvgForQsForCoffee(bulletin, listId, logger);
        } else if (builderId == 3) {
            // List owner token.
            return generateSvgForQsForPitcherDelivery(bulletin, listId, logger);
        } else if (builderId == 4) {
            // List user token.
            return generateSvgForDeliveryRecord(user, bulletin, listId, logger);
        } else {
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #1: Coffee with $CROISSANT
    /// -----------------------------------------------------------------------

    function qsForCroissant(
        TokenTitle memory title,
        TokenSource memory source
    ) public view returns (string memory) {
        return
            JSON._formattedMetadata(
                title.name,
                title.desc,
                generateSvgForQsForCroissant(
                    source.bulletin,
                    source.listId,
                    source.logger
                )
            );
    }

    function generateSvgForQsForCroissant(
        address bulletin,
        uint256 listId,
        address logger
    ) public view returns (string memory) {
        List memory list;
        (bulletin != address(0))
            ? list = IBulletin(bulletin).getList(listId)
            : list;

        (
            uint256 percentage,
            uint256 score,
            uint256 numOfCoffee
        ) = getResponseByCroissant(bulletin, listId, logger);

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
                buildTitle(list.title),
                buildNumericalHeader(numOfCoffee, "# of cups"),
                buildQaWithNumericalResponse(
                    "Did you have coffee with food?",
                    percentage,
                    " % said yes",
                    160
                ),
                buildQaWithNumericalResponse(
                    "How are you feeling?",
                    score,
                    " / 10",
                    210
                ),
                buildSignature(list.owner),
                "</svg>"
            );
    }

    function getResponseByCroissant(
        address bulletin,
        uint256 listId,
        address logger
    )
        public
        view
        returns (uint256 percentage, uint256 score, uint256 numOfCoffee)
    {
        Touchpoint memory tp;
        uint256 didHaveFood;
        uint256 _score;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(
                bulletin,
                listId,
                uint256(0)
            );

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    tp = ILog(logger).getTouchpointByItemIdByNonce(
                        bulletin,
                        listId,
                        uint256(0),
                        i
                    );

                    // Retrieve tp with CROISSANT (1 << 5) role only.
                    // Decode data and tally user response.
                    if (((tp.role >> 5) & 1) == 1) {
                        (didHaveFood, _score) = abi.decode(
                            tp.data,
                            (uint256, uint256)
                        );

                        unchecked {
                            percentage += didHaveFood;
                            score += _score;
                            ++numOfCoffee;
                        }
                    }

                    unchecked {
                        percentage = (percentage * 100) / numOfCoffee;
                        score = score / numOfCoffee;
                    }
                }
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #2: Coffee with $COFFEE
    /// -----------------------------------------------------------------------

    function qsForCoffee(
        TokenTitle memory title,
        TokenSource memory source
    ) public view returns (string memory) {
        return
            JSON._formattedMetadata(
                title.name,
                title.desc,
                generateSvgForQsForCoffee(
                    source.bulletin,
                    source.listId,
                    source.logger
                )
            );
    }

    function generateSvgForQsForCoffee(
        address bulletin,
        uint256 listId,
        address logger
    ) public view returns (string memory) {
        List memory list;
        (bulletin != address(0))
            ? list = IBulletin(bulletin).getList(listId)
            : list;

        (
            uint256 costOfCups,
            uint256 costOfLabor,
            uint256 costOfBenefits,
            uint256 numOfCoffee
        ) = getResponseByCoffee(bulletin, listId, logger);

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
                buildTitle(list.title),
                buildNumericalHeader(numOfCoffee, "# of cups"),
                buildQaWithCurrencyResponse(
                    "Cost of Cups",
                    costOfCups,
                    " ($)",
                    160
                ),
                buildQaWithCurrencyResponse(
                    "Cost of Labor",
                    costOfLabor,
                    " ($)",
                    210
                ),
                buildQaWithCurrencyResponse(
                    "Cost of Labor Benefits",
                    costOfBenefits,
                    " ($)",
                    260
                ),
                buildSignature(list.owner),
                "</svg>"
            );
    }

    function getResponseByCoffee(
        address bulletin,
        uint256 listId,
        address logger
    )
        public
        view
        returns (
            uint256 costOfCups,
            uint256 costOfLabor,
            uint256 costOfBenefits,
            uint256 numOfCoffee
        )
    {
        Touchpoint memory tp;

        uint256 _costOfCups;
        uint256 _costOfLabor;
        uint256 _costOfBenefits;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(
                bulletin,
                listId,
                uint256(0)
            );

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    tp = ILog(logger).getTouchpointByItemIdByNonce(
                        bulletin,
                        listId,
                        uint256(0),
                        i
                    );

                    // Retrieve tp with STAFF (1 << 7) role only.
                    // Decode data and tally user response.
                    if (((tp.role >> 7) & 1) == 1) {
                        (_costOfCups, _costOfLabor, _costOfBenefits) = abi
                            .decode(tp.data, (uint256, uint256, uint256));

                        unchecked {
                            costOfCups += _costOfCups;
                            costOfLabor += _costOfLabor;
                            costOfBenefits += _costOfBenefits;
                            ++numOfCoffee;
                        }
                    }
                }
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #3: Customer Response for Pitcher Qs
    /// -----------------------------------------------------------------------

    function qsForPitcherDelivry(
        TokenTitle memory title,
        TokenSource memory source
    ) public view returns (string memory) {
        return
            JSON._formattedMetadata(
                title.name,
                title.desc,
                generateSvgForQsForPitcherDelivery(
                    source.bulletin,
                    source.listId,
                    source.logger
                )
            );
    }

    function generateSvgForQsForPitcherDelivery(
        address bulletin,
        uint256 listId,
        address logger
    ) public view returns (string memory) {
        List memory list = IBulletin(bulletin).getList(listId);

        (
            uint256 costOfDelivery,
            uint256 costOfLabor,
            uint256 costOfRecycling,
            uint256 numOfPitchers
        ) = getResponseByPitcherDelivery(bulletin, listId, logger);

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
                buildTitle(list.title),
                buildNumericalHeader(numOfPitchers, "# of pitchers"),
                buildQaWithCurrencyResponse(
                    "Cost of Delivery",
                    costOfDelivery,
                    " ($)",
                    160
                ),
                buildQaWithCurrencyResponse(
                    "Cost of Labor",
                    costOfLabor,
                    " ($)",
                    210
                ),
                buildQaWithCurrencyResponse(
                    "Cost to Recycle",
                    costOfRecycling,
                    " ($)",
                    260
                ),
                buildSignature(list.owner),
                "</svg>"
            );
    }

    function getResponseByPitcherDelivery(
        address bulletin,
        uint256 listId,
        address logger
    )
        public
        view
        returns (
            uint256 costOfDelivery,
            uint256 costOfLabor,
            uint256 costOfRecycling,
            uint256 numOfPitchers
        )
    {
        Touchpoint memory tp;

        uint256 _costOfDelivery;
        uint256 _costOfLabor;
        uint256 _costOfRecycling;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(
                bulletin,
                listId,
                uint256(0)
            );

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    tp = ILog(logger).getTouchpointByItemIdByNonce(
                        bulletin,
                        listId,
                        uint256(0),
                        i
                    );

                    // Retrieve tp with STAFF (1 << 7) role only.
                    // Decode data and tally user response.
                    if (((tp.role >> 7) & 1) == 1) {
                        (_costOfDelivery, _costOfLabor, _costOfRecycling) = abi
                            .decode(tp.data, (uint256, uint256, uint256));

                        unchecked {
                            costOfDelivery += _costOfDelivery;
                            costOfLabor += _costOfLabor;
                            costOfRecycling += _costOfRecycling;
                            ++numOfPitchers;
                        }
                    }
                }
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #4: Helper's Track Record
    /// -----------------------------------------------------------------------

    function deliveryRecord(
        TokenTitle memory title,
        TokenSource memory source
    ) public view returns (string memory) {
        return
            JSON._formattedMetadata(
                title.name,
                title.desc,
                generateSvgForDeliveryRecord(
                    source.user,
                    source.bulletin,
                    source.listId,
                    source.logger
                )
            );
    }

    function generateSvgForDeliveryRecord(
        address user,
        address bulletin,
        uint256 listId,
        address logger
    ) public view returns (string memory) {
        List memory list;
        (bulletin != address(0))
            ? list = IBulletin(bulletin).getList(listId)
            : list;

        (
            uint256 numOfDeliveries,
            uint256 numOfRecyling
        ) = getDeliveryTaskCompletions(bulletin, listId, user, logger);

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
                buildTitle(string.concat("Helper ID ", shorten(user))),
                buildHeader(list.title),
                buildQaWithNumericalResponse(
                    "# of Pitchers Delivered",
                    numOfDeliveries,
                    "",
                    140
                ),
                buildQaWithNumericalResponse(
                    "# of Pitchers Recycled",
                    numOfRecyling,
                    "",
                    190
                ),
                "</svg>"
            );
    }

    function getDeliveryTaskCompletions(
        address bulletin,
        uint256 listId,
        address user,
        address logger
    ) public view returns (uint256 numOfDeliveries, uint256 numOfRecyling) {
        if (logger != address(0)) {
            uint256 logId = ILog(logger).lookupLogId(
                user,
                keccak256(abi.encodePacked(bulletin, listId))
            );

            Touchpoint[] memory tps = ILog(logger).getTouchpointsByLog(logId);

            uint256 length = tps.length;

            for (uint256 i; i < length; ++i) {
                // Retrieve tp with STAFF (1 << 7) role only.
                // Data retrieval condition.
                if (((tps[i].role >> 7) & 1) == 1) {
                    if (tps[i].itemId == 5 && tps[i].pass) {
                        unchecked {
                            ++numOfDeliveries;
                        }
                    }

                    if (tps[i].itemId == 6 && tps[i].pass) {
                        unchecked {
                            ++numOfRecyling;
                        }
                    }
                }
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Helper
    /// -----------------------------------------------------------------------

    function buildTitle(
        string memory title
    ) public pure returns (string memory) {
        return
            string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "40"),
                        SVG._prop("font-size", "20"),
                        SVG._prop("fill", "#00040a")
                    ),
                    title
                ),
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "#FFBE0B"),
                        SVG._prop("x", "20"),
                        SVG._prop("y", "50"),
                        SVG._prop("width", "160"),
                        SVG._prop("height", "5")
                    ),
                    SVG.NULL
                )
            );
    }

    function buildHeader(
        string memory header
    ) public pure returns (string memory) {
        return
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                header
            );
    }

    function buildNumericalHeader(
        uint256 num,
        string memory str
    ) public pure returns (string memory) {
        return
            string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "70"),
                        SVG._prop("y", "115"),
                        SVG._prop("font-size", "40"),
                        SVG._prop("fill", "#00040a")
                    ),
                    SVG._uint2str(num)
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "155"),
                        SVG._prop("y", "115"),
                        SVG._prop("font-size", "15"),
                        SVG._prop("fill", "#899499")
                    ),
                    str
                )
            );
    }

    function buildQaWithNumericalResponse(
        string memory prompt,
        uint256 result,
        string memory subtext,
        uint256 yValue
    ) public pure returns (string memory) {
        return
            string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", SVG._uint2str(yValue)),
                        SVG._prop("font-size", "10"),
                        SVG._prop("fill", "#808080")
                    ),
                    string.concat(prompt, ": ")
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", SVG._uint2str(yValue + 20)),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "#000000")
                    ),
                    string.concat(SVG._uint2str(result), subtext)
                )
            );
    }

    function buildQaWithCurrencyResponse(
        string memory prompt,
        uint256 amount,
        string memory subtext,
        uint256 yValue
    ) public pure returns (string memory) {
        return
            string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", SVG._uint2str(yValue)),
                        SVG._prop("font-size", "10"),
                        SVG._prop("fill", "#808080")
                    ),
                    string.concat(prompt, ": ")
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", SVG._uint2str(yValue + 20)),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "#000000")
                    ),
                    string.concat(convertToCurrencyForm(amount), subtext)
                )
            );
    }

    function buildSignature(address addr) public pure returns (string memory) {
        return
            SVG._text(
                string.concat(
                    SVG._prop("x", "200"),
                    SVG._prop("y", "285"),
                    SVG._prop("font-size", "9"),
                    SVG._prop("fill", "#c4c7c4")
                ),
                string.concat("by ", shorten(addr))
            );
    }

    function buildProgressBar(
        uint256 flavor
    ) public pure returns (string memory) {
        return
            string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "30"),
                        SVG._prop("y", "160"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "#7f7053")
                    ),
                    "Flavor"
                ),
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "#ffecb6"),
                        SVG._prop("x", "80"),
                        SVG._prop("y", "145"),
                        SVG._prop("width", "150"),
                        SVG._prop("height", "20"),
                        SVG._prop("rx", "2")
                    ),
                    SVG.NULL
                ),
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "#da2121"),
                        SVG._prop("x", "80"),
                        SVG._prop("y", "145"),
                        SVG._prop("width", SVG._uint2str(flavor)),
                        SVG._prop("height", "20"),
                        SVG._prop("rx", "2")
                    ),
                    SVG.NULL
                )
            );
    }

    function buildTasksCompletions(
        address bulletin,
        List memory list
    ) public view returns (string memory) {
        if (list.owner != address(0)) {
            uint256 length = (list.itemIds.length > 3)
                ? 5
                : list.itemIds.length;
            string memory text;
            Item memory item;

            for (uint256 i; i < length; ++i) {
                item = IBulletin(bulletin).getItem(list.itemIds[i]);
                text = string.concat(
                    text,
                    SVG._text(
                        string.concat(
                            SVG._prop("x", "20"),
                            SVG._prop("y", SVG._uint2str(140 + 20 * i)),
                            SVG._prop("font-size", "12"),
                            SVG._prop("fill", "#808080")
                        ),
                        string.concat(
                            item.title,
                            ": ",
                            SVG._uint2str(
                                IBulletin(bulletin).runsByItem(list.itemIds[i])
                            )
                        )
                    )
                );
            }
            return text;
        } else {
            return SVG.NULL;
        }
    }

    // function buildTicker(address curve, uint256 curveId) public view returns (string memory) {
    //     uint256 priceToMint =
    //         (curveId == 0 || curve == address(0)) ? 0 : ITokenCurve(curve).getCurvePrice(true, curveId, 0);
    //     uint256 priceToBurn =
    //         (curveId == 0 || curve == address(0)) ? 0 : ITokenCurve(curve).getCurvePrice(false, curveId, 0);

    //     return string.concat(
    //         SVG._text(
    //             string.concat(
    //                 SVG._prop("x", "230"),
    //                 SVG._prop("y", "25"),
    //                 SVG._prop("font-size", "9"),
    //                 SVG._prop("fill", "#00040a")
    //             ),
    //             string.concat(unicode"🪙  ", convertToCurrencyForm(priceToMint), unicode" Ξ")
    //         ),
    //         SVG._text(
    //             string.concat(
    //                 SVG._prop("x", "230"),
    //                 SVG._prop("y", "40"),
    //                 SVG._prop("font-size", "9"),
    //                 SVG._prop("fill", "#00040a")
    //             ),
    //             string.concat(unicode"🔥  ", convertToCurrencyForm(priceToBurn), unicode" Ξ")
    //         )
    //     );
    // }

    /// -----------------------------------------------------------------------
    /// Utility
    /// -----------------------------------------------------------------------

    // credit: https://ethereum.stackexchange.com/questions/46321/store-literal-bytes4-as-string
    function shorten(address user) internal pure returns (string memory) {
        bytes4 _address = bytes4(abi.encodePacked(user));

        bytes memory result = new bytes(10);
        result[0] = bytes1("0");
        result[1] = bytes1("x");
        for (uint256 i = 0; i < 4; ++i) {
            result[2 * i + 2] = toHexDigit(uint8(_address[i]) / 16);
            result[2 * i + 3] = toHexDigit(uint8(_address[i]) % 16);
        }
        return string(result);
    }

    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1("0")) + d);
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return bytes1(uint8(bytes1("a")) + d - 10);
        }
        revert();
    }

    function convertToCurrencyForm(
        uint256 amount
    ) internal pure returns (string memory) {
        string memory decimals;
        for (uint256 i; i < 4; ++i) {
            uint256 decimalPoint = 1 ether / (10 ** i);
            if (amount % decimalPoint > 0) {
                decimals = string.concat(
                    decimals,
                    SVG._uint2str((amount % decimalPoint) / (decimalPoint / 10))
                );
            } else {
                decimals = string.concat(decimals, SVG._uint2str(0));
            }
        }

        return string.concat(SVG._uint2str(amount / 1 ether), ".", decimals);
    }
}
