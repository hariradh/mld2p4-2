#!/bin/bash
hn=mld_const.h
fn=mld_base_prec_type.F90
echo "/* This file was generated by a script using the $fn file as a basis. */" > $hn
echo '#ifndef MLD_CONST_H_' >> $hn
echo '#define MLD_CONST_H_' >> $hn
echo '#ifdef __cplusplus' >> $hn
echo 'extern "C" { ' >> $hn
echo '#endif' >> $hn
cat $fn | sed 's/=/= (/g;s/$/ )/g' | grep '\(^  *!\)\|parameter' | grep  '_\>'  | sed 's/^\s*//g;s/^.*:://g;s/\s*=\s*/ /g' | sed  's/,/\n/g;s/^ //g'  | tr '[:lower:]' '[:upper:]' | grep ^MLD | sed 's/^/#define /g' >> $hn
echo '#ifdef __cplusplus' >> $hn
echo '}' >> $hn
echo '#endif' >> $hn
echo '#endif' >> $hn
exit

