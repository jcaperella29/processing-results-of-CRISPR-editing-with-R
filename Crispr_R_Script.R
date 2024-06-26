# Load packages.
install.packages('devtools')
devtools::install_github('immunogenomics/presto')

library(Seurat)
library(SeuratData)
library(ggplot2)
library(patchwork)
library(scales)
library(dplyr)
library(reshape2)
library(mixtools)


# Download dataset using SeuratData.
InstallData(ds = "thp1.eccite")

# Setup custom theme for plotting.
custom_theme <- theme(
  plot.title = element_text(size=16, hjust = 0.5), 
  legend.key.size = unit(0.7, "cm"), 
  legend.text = element_text(size = 14))


# Load object.
eccite <- LoadData(ds = "thp1.eccite")


# Normalize protein.
eccite <- NormalizeData(
  object = eccite, 
  assay = "ADT", 
  normalization.method = "CLR", 
  margin = 2)

# Prepare RNA assay for dimensionality reduction: 
# Normalize data, find variable features and scale data.
DefaultAssay(object = eccite) <- 'RNA'
eccite <- NormalizeData(object = eccite) %>% FindVariableFeatures() %>% ScaleData()

# Run Principle Component Analysis (PCA) to reduce the dimensionality of the data.
eccite <- RunPCA(object = eccite)

# Run Uniform Manifold Approximation and Projection (UMAP) to visualize clustering in 2-D.
eccite <- RunUMAP(object = eccite, dims = 1:40)

# Generate plots to check if clustering is driven by biological replicate ID, 
# cell cycle phase or target gene class.
p1 <- DimPlot(
  object = eccite, 
  group.by = 'replicate', 
  label = F, 
  pt.size = 0.2, 
  reduction = "umap", cols = "Dark2", repel = T) +
  scale_color_brewer(palette = "Dark2") +
  ggtitle("Biological Replicate") +
  xlab("UMAP 1") +
  ylab("UMAP 2") +
  custom_theme

p2 <- DimPlot(
  object = eccite, 
  group.by = 'Phase', 
  label = F, pt.size = 0.2, 
  reduction = "umap", repel = T) + 
  ggtitle("Cell Cycle Phase") +
  ylab("UMAP 2") +
  xlab("UMAP 1") +
  custom_theme

p3 <- DimPlot(
  object = eccite, 
  group.by = 'crispr', 
  pt.size = 0.2, 
  reduction = "umap", 
  split.by = "crispr", 
  ncol = 1, 
  cols = c("grey39","goldenrod3")) + 
  ggtitle("Perturbation Status") +
  ylab("UMAP 2") +
  xlab("UMAP 1") +
  custom_theme

# Visualize plots.
((p1 / p2 + plot_layout(guides = 'auto')) | p3 )



# Calculate perturbation signature (PRTB).
eccite<- CalcPerturbSig(
  object = eccite, 
  assay = "RNA", 
  slot = "data", 
  gd.class ="gene", 
  nt.cell.class = "NT", 
  reduction = "pca", 
  ndims = 40, 
  num.neighbors = 20, 
  split.by = "replicate", 
  new.assay.name = "PRTB")



# Run mixscape.
eccite <- RunMixscape(
  object = eccite, 
  assay = "PRTB", 
  slot = "scale.data", 
  labels = "gene", 
  nt.class.name = "NT", 
  min.de.genes = 5, 
  iter.num = 10, 
  de.assay = "RNA", 
  verbose = F,
  prtb.type = "KO")

#isolate genes with high probality of knock_down

Meta_data<-eccite@meta.data
genes_and_probs<-subset(Meta_data,select = c("gene","mixscape_class_p_ko"))


genes_and_probs<-genes_and_probs[order(-genes_and_probs$mixscape_class_p_ko),]
unique_genes<-distinct(genes_and_probs, gene, .keep_all = TRUE)



high_probs_and_genes<-unique_genes[unique_genes$mixscape_class_p_ko == "1",]
knocked_out_genes<-high_probs_and_genes$gene

#exporting list of genes knocked out by CRIPR perturbation.

write.table(knocked_out_genes,"C:/Users/ccape/Downloads/knocked_out genes/results.txt")



  
  

# Calculate percentage of KO cells for all target gene classes.
df <- prop.table(table(eccite$mixscape_class.global, eccite$NT),2)

df2 <- reshape2::melt(df)
df2$Var2 <- as.character(df2$Var2)
test <- df2[which(df2$Var1 == "KO"),]
test <- test[order(test$value, decreasing = T),]
new.levels <- test$Var2
df2$Var2 <- factor(df2$Var2, levels = new.levels )
df2$Var1 <- factor(df2$Var1, levels = c("NT", "NP", "KO"))
df2$gene <- sapply(as.character(df2$Var2), function(x) strsplit(x, split = "g")[[1]][1])
df2$guide_number <- sapply(as.character(df2$Var2), 
                           function(x) strsplit(x, split = "g")[[1]][2])
df3 <- df2[-c(which(df2$gene == "NT")),]

p1 <- ggplot(df3, aes(x = guide_number, y = value*100, fill= Var1)) +
  geom_bar(stat= "identity") +
  theme_classic()+
  scale_fill_manual(values = c("grey49", "grey79","coral1")) + 
  ylab("% of cells") +
  xlab("sgRNA")

p1 + theme(axis.text.x = element_text(size = 18, hjust = 1), 
           axis.text.y = element_text(size = 18), 
           axis.title = element_text(size = 16), 
           strip.text = element_text(size=16, face = "bold")) + 
  facet_wrap(vars(gene),ncol = 5, scales = "free") +
  labs(fill = "mixscape class") +theme(legend.title = element_text(size = 14),
                                       legend.text = element_text(size = 12))


# Explore the perturbation scores of cells.
PlotPerturbScore(object = eccite, 
                 target.gene.ident = "IFNGR2", 
                 mixscape.class = "mixscape_class", 
                 col = "coral2") +labs(fill = "mixscape class")

# Inspect the posterior probability values in NP and KO cells.
VlnPlot(eccite, "mixscape_class_p_ko", idents = c("NT", "IFNGR2 KO", "IFNGR2 NP")) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5),axis.text = element_text(size = 16) ,plot.title = element_text(size = 20)) + 
  NoLegend() +
  ggtitle("mixscape posterior probabilities")


# Run DE analysis and visualize results on a heatmap ordering cells by their posterior 
# probability values.
Idents(object = eccite) <- "gene"
MixscapeHeatmap(object = eccite, 
                ident.1 = "NT", 
                ident.2 = "IFNGR2", 
                balanced = F, 
                assay = "RNA", 
                max.genes = 20, angle = 0, 
                group.by = "mixscape_class", 
                max.cells.group = 300, 
                size=6.5) + NoLegend() +theme(axis.text.y = element_text(size = 16))



# Show that only IFNG pathway KO cells have a reduction in PD-L1 protein expression.
VlnPlot(
  object = eccite, 
  features = "adt_PDL1", 
  idents = c("NT","JAK2","STAT1","IFNGR1","IFNGR2", "IRF1"), 
  group.by = "gene", 
  pt.size = 0.2, 
  sort = T, 
  split.by = "mixscape_class.global", 
  cols = c("coral3","grey79","grey39")) +
  ggtitle("PD-L1 protein") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), plot.title = element_text(size = 20), axis.text = element_text(size = 16))



#Remove non-perturbed cells and run LDA to reduce the dimensionality of the data.
Idents(eccite) <- "mixscape_class.global"
sub <- subset(eccite, idents = c("KO", "NT"))

# Run LDA.
sub <- MixscapeLDA(
  object = sub, 
  assay = "RNA", 
  pc.assay = "PRTB", 
  labels = "gene", 
  nt.label = "NT", 
  npcs = 10, 
  logfc.threshold = 0.25, 
  verbose = F)

# Use LDA results to run UMAP and visualize cells on 2-D. 
# Here, we note that the number of the dimensions to be used is equal to the number of 
# labels minus one (to account for NT cells).
sub <- RunUMAP(
  object = sub,
  dims = 1:11,
  reduction = 'lda',
  reduction.key = 'ldaumap',
  reduction.name = 'ldaumap')

# Visualize UMAP clustering results.
Idents(sub) <- "mixscape_class"
sub$mixscape_class <- as.factor(sub$mixscape_class)

# Set colors for each perturbation.
col = setNames(object = hue_pal()(12),nm = levels(sub$mixscape_class))
names(col) <- c(names(col)[1:7], "NT", names(col)[9:12])
col[8] <- "grey39"

p <- DimPlot(object = sub, 
             reduction = "ldaumap", 
             repel = T, 
             label.size = 5, 
             label = T, 
             cols = col) + NoLegend()

p2 <- p+ 
  scale_color_manual(values=col, drop=FALSE) + 
  ylab("UMAP 2") +
  xlab("UMAP 1") +
  custom_theme
p2

#orginal code is from https://satijalab.org/seurat/articles/mixscape_vignette. I added some lines to allow the user to see what genes were knocked out.
