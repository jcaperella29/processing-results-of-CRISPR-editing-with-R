# processing-results-of-CRISPR-editing-with-R
First needed libraries are imported.
A theme for plots is defined and the dataset is read in and tranformed into a SEURAT object
data is then normllizied and scaled .
Then using a umap and pca the  dimensionality of the data is reduced.

Then  plots are  generated  to check if clustering is driven by biological replicate ID, 
cell cycle phase or target gene class.
Then perturbation signature is  calculated
Then mixscape is run.
next we isolate genes with high probability of knock down and export the list of those genes as a text file.

Then calculate the percentage of the knock-out cells for all gene classes.

then we  explore the perturbation scores of cells.

Next we inspect the posterior probability values in NP and KO cells

Then we  run DE analysis and visualize results on a heatmap ordering cells by their posterior  probability values.

We Show that only IFNG pathway KO cells have a reduction in PD-L1 (our protien of interest )protein expression.

Then we remove non-perturbed cells and run LDA to reduce the dimensionality of the data

Finally we use LDA results to run UMAP and visualize cells on 2-D. 
