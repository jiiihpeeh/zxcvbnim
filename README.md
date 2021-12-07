This is a zxcvbn clone  for Nim. Zxcvbn is a low resource estimator for a realistic password strength. This is based on a Python implementation (https://github.com/dwolfhub/zxcvbn-python).  

It does not support Decimal notation (and hence produces  a valid json string). Decimal / bigInt score according to my understanding is a way to represent exact information. Zxcvbn(im) is a tool for *estimation* and only the magnitude should matter hence this is omitted for the sake of simplicity.

```
nimble install https://gitlab.com/jiiihpeeh/zxcvbnim/
```

The example directory includes has a sourcecode  file for a standalone app. It compiles to a single file and binary should take under 2 megabytes of space (there is no need for a nim environment after compilation).

Install the nimble package as shown above and download the example directory. 
Compilation  inside the example/ directory:
```
nim c zxcvbnim_cli.nim
```
