# WP9S2LU_Price
## Price indices with ML based imputation

Price indices are traditionally constructed by comparing the prices of identical products across two time periods. However, in markets with dynamic product assortments, this matched-model approach—limited to products available in both periods—can be insufficient. To address this, prices can be imputed for products that appear in only one of the two comparison periods.

Imputed prices are typically estimated using models that relate observed prices to a set of price-determining characteristics. A common method involves semi-logarithmic multiple regression. In this project, we explore the application of machine learning (ML) techniques to enhance the imputation of such missing prices.

Our use case involves data collected from the website of a major consumer electronics retailer. The dataset forms an imbalanced panel, where prices are missing in periods when a product is not sold. Alongside price data, a rich set of product features is available to describe each item.

This real-world example helps us to validate the ML-based imputation approach and assess its effectiveness in supporting quality adjustment procedures within 


