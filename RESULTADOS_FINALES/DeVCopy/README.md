## Original Model

Results from the original model. At first, this model yielded very good results with an F1-score of > 0.9. However, after digging into the code a bit, I discovered that the model was trained using data balancing, which equalized the number of regions with CNVs and normal regions, resulting in 80–90% of the data being discarded.


