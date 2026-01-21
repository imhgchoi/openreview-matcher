#!/bin/bash


run () {
    local file=$1
    local output=error.txt
    #> $output
    echo $file 

    # 1) check too short paper
    PAGE_NUM=`pdfinfo $file | grep "Pages" | sed s/"^.* "/""/g`
    if [ $PAGE_NUM -gt 4 ]
    then
        echo "[1] Placeholders ... PASS"
    else
        echo "[1] Placeholders ... FAIL: Page num = $PAGE_NUM"
        echo $file >> $output
        echo "Fewer than 5 pages:" $PAGE_NUM >> $output
    fi

    # 2) not anonymous
    FIRST_PAGE=`pdftotext -f 1 -l 1 $file -`
    if [[ $FIRST_PAGE == *"Anonymous"* ]] || [[ $FIRST_PAGE == *"Firstname1 Lastname1"* ]] || [[ $FIRST_PAGE == *"Paper ID"* ]]
    then
        echo "[2] Anonymous ... PASS"
	else
        echo "[2] Anonymous ... FAIL"
        echo $file >> $output
        echo "Not Anonymous" >> $output
	fi

    # 3) incomplete footnote
    if [[ $FIRST_PAGE == *"Machine Learning (ICML)"* ]] && [[ $FIRST_PAGE == *"anon.email@"* ]]
    then
        echo "[3] Footnote ... PASS"
    else
        echo "[3] Footnote ... FAIL"
        echo $file >> $output
        echo "Incomplete footnote" >> $output
    fi 

    # 4) main content exceeds 8-pages
    if [[ $PAGE_NUM -lt 9 ]]
    then 
    	echo "[4] Content ... PASS"
    else
    	CONTENT=`pdftotext -f 1 -l 8 $file -`
        LINE3=`pdftotext -f 9 -l 9 $file - | head -n 3` 
        LINE3L=$(echo "$LINE3" | tr '[:upper:]' '[:lower:]')

    	if [[ $CONTENT == *"References"* ]] || [[ $CONTENT == *"Bibliography"* ]] || [[ $CONTENT == *"Acknowledgement"* ]] || [[ $CONTENT == *"Impact Statement"* ]] || [[ $CONTENT == *"REFERENCE"* ]] || [[ $CONTENT == *"Broader Impact"* ]]
        then
            echo "[4] Content ... PASS"
        elif [[ $LINE3L == *"reference"* ]] || [[ $LINE3L == *"bibliography"* ]] || [[ $LINE3L == *"statement"* ]] || [[ $LINE3L == *"impact"* ]] || [[ $LINE3L == *"ethics"* ]] || [[ $LINE3L == *"acknowledgement"* ]] || [[ $LINE3L == *"software"* ]] || [[ $LINE3L == *"accessibility"* ]]
        then
            echo "[4] Content ... PASS"
        else
            echo "[4] Content ... FAIL"
            echo $file >> $output
            echo "Page exceed:" $PAGE_NUM >> $output
    	fi
    fi

    # 5) example paper
    if [[ $FIRST_PAGE == *"Formatting Instructions"* ]] || [[ $FIRST_PAGE == *"http://icml.cc/"* ]] || [[ $FIRST_PAGE == *"This document provides a basic paper template"* ]]
    then
        echo "[5] Paper ... FAIL"
        echo $file >> $output
        echo "Example paper" >> $output
    else
        echo "[5] Paper ... PASS"
    fi

    # 6) no impact statement
    TEXT=`pdftotext -f 1 -l $PAGE_NUM $file -`
    if [[ $TEXT == *"Impact Statement"* ]] || [[ $TEXT == *"Broader Impact"* ]]
    then
        echo "[6] Impact ... PASS"
    else
            echo "[6] Impact ... FAIL"
            echo $file >> $output
            echo "No Impact" >> $output
    fi
    
}


for p in *.pdf;
do
    run $p
done

