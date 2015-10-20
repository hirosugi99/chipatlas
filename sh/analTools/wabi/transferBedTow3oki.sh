#!/bin/sh
#$ -S /bin/sh

# sh chipatlas/sh/analTools/wabi/transferBedTow3oki.sh chipatlas
projectDir=$1
tmpDir=tmpDirFortransferBedTow3oki
rm -rf $tmpDir
mkdir -p $tmpDir/results
mkdir -p $tmpDir/lineNum

for Genome in `ls $projectDir/results/`; do
  mkdir -p $tmpDir/results/$Genome/public
  for bed in `echo $projectDir/results/$Genome/public/*.AllAg.AllCell.bed`; do
    outBed=$tmpDir/results/$Genome/public/`basename $bed`
    let i=$i+1
    # BED ファイルの整形、5000万行ごとに分割し、core dump を防ぐ
    echo "tail -n+2 $bed| tr '=;' '\t\t'| cut -f 1,2,3,5 > $outBed;\
          split -l 50000000 $outBed $outBed. ;\
          wc -l $outBed > $tmpDir/lineNum/$i;\
          rm $outBed"| qsub -N trfB2w3 -l short -o /dev/null -e /dev/null
  done
done

while :; do
  qN=`qstat| awk '$3 == "trfB2w3"'| wc -l`
  if [ "$qN" -eq 0 ]; then
    break
  else
    echo "Waiting for converting Bed files..."
    date
    sleep 60
  fi
done

# BED ファイルの行数を集計。
fileList="$projectDir/lib/assembled_list/fileList.tab"
cat $tmpDir/lineNum/*| tr ' /' '\t\t'| awk -F '\t' -v fileList=$fileList '
BEGIN {
  while ((getline < fileList) > 0) {
    x[$1 ".bed",$2] = $2 "\t" $3 "\t" $5 "\t" $7
  }
} {
  print x[$6,$4] "\t" $1
}' > $tmpDir/lineNum.tsv

# NBDC サーバの lib フォルダに転送
nbdc
put tmpDirFortransferBedTow3oki/lineNum.tsv -o data/lib/lineNum.tsv
bye

# w3oki アカウントに Bed ファイルをコピー
w3oki
rm -rf w3oki/tmpDirFortransferBedTow3oki
for genome in `ls tmpDirFortransferBedTow3oki/results/`; do
  dirOkiS="tmpDirFortransferBedTow3oki/results/$genome/public"        # okishinya アカウントの public フォルダ
  dirWab1="w3oki/tmpDirFortransferBedTow3oki/results/$genome/public"  # w3oki アカウントの 一時的 public フォルダ
  dirWab2="w3oki/$projectDir/results/$genome/public"                    # w3oki アカウントの 計算用 public フォルダ
  mkdir -p w3oki/tmpDirFortransferBedTow3oki/results/$genome
  cp -r "$dirOkiS" "$dirWab1"
  mv "$dirWab2" "$dirWab2"_old
  mv "$dirWab1" "$dirWab2"
  rm -r "$dirWab2"_old
done
rm -r "$dirWab1"
exit

