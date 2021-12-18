const path = require('path');
const fs = require('fs');
const solc = require('solc');
const { ethers } = require('ethers')

exports.handler = async function(event, context) {

    // console.log(event);

    const templateName = 'EthTemplate.sol'
    const templatesFolderPath = path.join(__dirname, 'templates')
    const contractContents = fs.readFileSync(path.join(templatesFolderPath, templateName), 'utf8')

    console.log('read EthTemplate file')

    // fs.writeFileSync(path.join(__dirname, 'CompiledContract.sol'), eval(contractContents))

    function findImports(missingImport) {
        if (missingImport.startsWith('@openzeppelin')) {
            console.log(`reading import ${missingImport}`)
            return {
              contents: fs.readFileSync(path.join(__dirname, missingImport), 'utf8')
            };
        }
        else {
            console.log(`import ${missingImport} not found`);
            return { error: 'File not found' };
        }
    }


    const input = {
        language: 'Solidity',
        sources: {
            [templateName]: {
                content: eval(contractContents)
            },/*
            'AnotherFileWithAnContractToCompile.sol': {
                content: fs.readFileSync(path.resolve(__dirname, 'contracts', 'AnotherFileWithAnContractToCompile.sol'), 'utf8')
            }*/
        },
        settings: {
            outputSelection: { // return everything
                '*': {
                    '*': ['*']
                }
            }
        }
    }

    console.log('about to launch solc compiler')
    
    const output = JSON.parse(
        solc.compile(JSON.stringify(input), { import: findImports })
    );

    console.log(output)

    console.log('solc compiler done')
        
    const { abi, evm } = output.contracts[templateName]['StonerSharks']

    // console.log(output.contracts[templateName])

    return {
        statusCode: 200,
        body: JSON.stringify({
            abi,
            bytecode: `0x${evm.bytecode.object}`
        })
    };
}