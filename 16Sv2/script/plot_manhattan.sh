#!/bin/bash
set -e

### Default parameter
otu_table_css=otu_table_css.txt
compare=group_compare.txt
design=design.txt
execute='TRUE'
otu_table=otu_table.txt
ist='FALSE' # install package, default FALSE
merge_group='FALSE' # combine group1.group2 as new group name, not allow TRUE with group_order
output='result_k1-c' # default work directory, remove low abundance < .1% and p__Cyanobacteria,p__Chloroflexi
pair_group='TRUE' # when pair_group have value turn TRUE
short_tax='TRUE'
taxonomy=rep_seqs_tax.txt
group_order='FALSE' # order group by input list, not allow TRUE with merge_group
select1='FALSE' # filter first group1 info
select2='FALSE' # filter first group2 info
tax_number=5 # set taxonomy number in stackplot
width=10
height=4
text_size=6

# 设置差异OTU筛选标准
# 统计方法基于负二项分布的普通线性模型lrt，wilcoxon秩和检验
method="edgeR"
# pvalue常用0.05, 0.01, 0.001
pvalue=0.01
# fdr常用fdr/none
fdr=0.05
# logFC常用0, 1.5, 2, 4倍，对应0, 0.585, 1, 2；此外还有1.3和1.7倍对应0.379和0.766
logFC=0.379
thre_per=0.005 # threshold for show phylum/family
ymax=20 # manhattan plot ylab max size
fold_max=4 # fold change max for volcano plot
# style include css, percentage, rpm default none
style=none
# 调整图例数量，9与stackplot一致
top_tax=9
culture='FALSE'

# Function for script description and usage
usage()
{
cat <<EOF >&2
Usage:
-------------------------------------------------------------------------------
Filename:    plot_manhattan.sh
Revision:    1.0
Date:        2018/5/22
Author:      Yong-Xin Liu
Email:       yxliu@genetics.ac.cn
Website:     http://bailab.genetics.ac.cn/
Description: This script is used to perform calculate different abundance OTUs, and statistic by edgeR.
Notes:       Visualize in volcano plot, manhattan plot and heatmap
-------------------------------------------------------------------------------
Copyright:   2017 (c) Yong-Xin Liu
License:     GPL
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License 
as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
If any changes are made to this script, please mail me a copy of the changes
-------------------------------------------------------------------------------
Version 1.0 2018/5/22
Input compared result as input
Version 1.1 2018/6/14
注释门改为门+变形菌纲着色，X轴添加标签


# All input and output should be in -o directory, or give relative -o path, or absolute path
# Input files: design.txt, otu_table.txt, rep_seqs_tax.txt, compare.txt and otu_table_css.txt

# 1. result/compare/LTEJ-LIND_all.txt
LTEJ_LIND       logFC   logCPM  PValue  FDR     level   Kingdom  Phylum  Class   Order   Family  Genus   Species MeanA   MeanB 
OTU_10  0.752   16.205  5.09336260168295e-06    7.33866150005798e-06    Enriched        Bacteria        Proteobacteria  Betapr
OTU_1013        -0.686  8.826   9.35229611739564e-05    0.000118918230004482    Depleted        Bacteria        Proteobacteria

# Output file
1. Manhattan plot: man_otu_SampleAvsSampleB.pdf

OPTIONS:
	-a css OTU table, default in otu_table_css.txt
	-b pvalue threshold, default=0.05
	-c pairs needed to do comparasion, compare.txt
	-d design for each samples, default design.txt
	-e execuate Rscript, TRUE or FALSE
	-f OTU table, default in otu_table.txt
	-g group order by group1 list, default FALSE, not allow both TRUE with -m merge group, when B exist is TRUE
	-h figure height, default 2.5
	-i install package TRUE or FALSE, default FALSE
	-m merge group 1 and group 2 as new group name, default FALSE, not allow both TRUE with -g group order
	-n show top N taxonomy number, default 5, recommend phylum is 5-10
	-o output director, default result_k1-c/
	-p default TRUE for compare group, set FALSE to loop each pair group
	-s text size, default 8
	-t default rep_seqs_tax.txt, taxonomy of all OTU
	-w figure width, default 4
	-A group1 name
	-B group1 selected list
	-C group2 name
	-D group2 selected list
	-F FDR correction method, default "fdr", no result can change to "none"
	-L log fold change (logFC), default 1.3, alternative 2, 4
	-I culture information, default FALSE, can TRUE
	-S sample abundance style, default none, alternative css, rpm and percentage
	-M method, wilcoxon or lrt
	-h/? show help of script

Example:
	plot_manhattan.sh -i DA_OTU -o DA_OTU.pdf
EOF
}


# Analysis parameter
while getopts "a:b:c:d:e:f:g:h:i:m:o:p:s:t:w:A:B:C:D:F:L:S:I:M:Y:" OPTION
do
	case $OPTION in
		a)
			otu_table_css=$OPTARG
			;;
		b)
			pvalue=$OPTARG
			;;
		c)
			compare=$OPTARG
			;;
		d)
			design=$OPTARG
			;;
		e)
			execute=$OPTARG
			;;
		f)
			norm_otu=$OPTARG
			;;
		g)
			group_order=$OPTARG
			;;
		h)
			height=$OPTARG
			;;
		i)
			input=$OPTARG
			;;
		m)
			merge_group=$OPTARG
			;;
		n)
			top_tax=$OPTARG
			;;
		o)
			output=$OPTARG
			;;
		p)
			pair_group=$OPTARG
			;;
		s)
			text_size=$OPTARG
			;;
		t)
			taxonomy=$OPTARG
			;;
		w)
			width=$OPTARG
			;;
		A)
			g1=$OPTARG
			;;
		B)
			g1_list=$OPTARG
			select1=TRUE
			;;
		C)
			g2=$OPTARG
			;;
		D)
			g2_list=$OPTARG
			select2=TRUE
			;;
		F)
			fdr=$OPTARG
			;;
		L)
			logFC=$OPTARG
			;;
		S)
			style=$OPTARG
			;;
		I)
			culture=$OPTARG
			;;
		M)
			method=$OPTARG
			;;
		Y)
			ymax=$OPTARG
			;;
		?)
			usage
			exit 1
			;;
	esac
done



cat <<END >script/plot_manhattan.r
# 2.1 安装CRAN来源常用包
site="https://mirrors.tuna.tsinghua.edu.cn/CRAN"
# 依赖包列表：参数解析、数据变换、绘图和开发包安装、安装依赖、ggplot主题
package_list = c("Biobase","edgeR","ggplot2","gplots","grid","RColorBrewer","reshape2","VennDiagram","dplyr","pheatmap")
# 判断R包加载是否成功来决定是否安装后再加载
for(p in package_list){
	if(!suppressWarnings(suppressMessages(require(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))){
		install.packages(p, repos=site)
		suppressWarnings(suppressMessages(library(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))
  }
}


# Set ggplot2 drawing parameter, such as axis line and text size, lengend and title size, and so on.
main_theme = theme(panel.background=element_blank(), panel.grid=element_blank(),
	axis.line.x=element_line(size=.5, colour="black"), axis.line.y=element_line(size=.5, colour="black"),
	axis.ticks=element_line(color="black"), axis.text=element_text(color="black", size=${text_size}),
	legend.position="right", legend.background=element_blank(), legend.key=element_blank(), legend.text= element_text(size=${text_size}),
	text=element_text(family="sans", size=${text_size}))

# 实验差异比较结果
x = read.table("${input}", header=T, row.names= 1, sep="\t", stringsAsFactors = F) 
# 只提取前14列
x = x[,1:14]
x = na.omit(x)

# P值求负对数
x\$neglogp = -log10(x\$PValue)

x\$otu=rownames(x)
x = arrange(x, Kingdom, Phylum, Class, Order, Family, Genus, Species)
x\$otu = factor(x\$otu, levels=x\$otu)   # set x order
x\$num = 1:dim(x)[1]

# 读取高丰度门，用于着色
# per= read.delim("result/tax/sum_p.txt", sep = "\t", row.names=1, header=T)
per= read.delim("result/tax/sum_pc.txt", sep = "\t", row.names=1, header=T)
mean = rowMeans(per)
per = as.data.frame(mean[order(mean, decreasing = T)])
top_tax=head(rownames(per), n=${top_tax})

# 将低丰度的门变为Low Abundance
# x\$tax = factor(x\$Phylum, levels=c(as.vector(unique(x\$Phylum)),"Low Abundance"))

# 将低丰度的门变为Low Abundance
x\$tax = x\$Phylum# factor(x\$Phylum, levels=c(as.vector(unique(x\$Phylum)),"Low Abundance"))

# 将门中 proteobacteria 替换为纲
x[x\$tax %in% "Proteobacteria",]\$tax =  x[x\$tax %in% "Proteobacteria",]\$Class # no level can get value

if (length(unique(x\$tax)) > length(top_tax)){
	x[!(x\$tax %in% top_tax),]\$tax = "Low Abundance" # no level can get value
}


# 调置标签顺序
label = unique(x\$tax)
label = label[!(label %in% "Low Abundance")] # 删除低丰度
x\$tax = factor(x\$tax, levels = c(label, "Low Abundance"))
# 计算标签中位数
temp = x[x\$tax %in% label, c("tax","num")]
mat_mean = aggregate(temp[,-1], by=temp[1], FUN=median) # mean


# 调整过大的负对数
if (max(x\$neglogp)>${ymax}){
  x[x\$neglogp>${ymax},]\$neglogp  = ${ymax}
}
colnames(x)[2]="log2CPM" 
# Manhattan plot
FDR = min(x\$neglogp[x\$level!="NotSig"])
p = ggplot(x, aes(x=num, y=neglogp, color=tax, size=log2CPM, shape=level)) +
  geom_point(alpha=.7) + 
  geom_hline(yintercept=FDR, linetype=2, color="lightgrey") +
  scale_shape_manual(values=c(25, 17, 20))+
  scale_size(breaks=c(5, 10, 15)) +
  labs(x="Taxonomy of OTUs", y="-log10(P)", title=paste("${input}", sep=" ")) +main_theme +
  theme(legend.position="top") +
  scale_x_continuous(breaks=mat_mean\$x, labels=mat_mean\$tax) + 
  theme(axis.text.x=element_text(angle=45, hjust=1, vjust=1)) # + ylim(0,${ymax})
  # ylim保持多组y轴范围一致，一般在最终出版时才使用
p
ggsave(file=paste("${input}_man_pc.pdf", sep=""), p, width = ${width}, height = ${height}, useDingbats=F)
ggsave(file=paste("${input}_man_pc.png", sep=""), p, width = ${width}, height = ${height})

END


if test "${execute}" == "TRUE";
then
	Rscript script/plot_manhattan.r
fi
