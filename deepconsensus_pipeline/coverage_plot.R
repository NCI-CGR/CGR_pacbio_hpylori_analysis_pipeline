library(ggplot2)

args <- commandArgs(TRUE)
plotname = unlist(strsplit(args[1], split='.depth', fixed=TRUE))[1]
contigname = unlist(strsplit(args[1], split='.', fixed=TRUE))[2]
plotname2 = paste(plotname, "png", sep="." )

png(filename = plotname2, 10, 7, "in", res = 300)

data_coverage <- read.table(args[1], header=FALSE, sep="\t")
colnames(data_coverage)=c("CONTIG", "POS", "DEPTH")

gg <- ggplot(data_coverage, aes(x=POS,  y=DEPTH))
gg + geom_line()+
labs(x = "Reference Position", y = "Coverage") +
ggtitle(paste("Coverage for",contigname, sep=" " )) +
theme(panel.grid = element_line(color = "grey", size = 0.5,linetype = 1), plot.title = element_text(hjust = 0.5)) +
theme(axis.line = element_line(size = 1, colour = "grey"),panel.background = element_rect(fill = "white"), panel.border = element_rect(colour = "black", fill=NA))
dev.off()


