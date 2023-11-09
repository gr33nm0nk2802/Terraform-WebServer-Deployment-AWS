# Introduction

In this demo project I am going to use a terraform to spin up an ubuntu web server. The project covers the following steps.

1. Creating a **VPC**.

2. Creating an **Internet Gateway**.

3. Creating a **Custom Route Table**.

4. Create a **Subnet**.

5. Associate a **Subnet** with the **Route Table**.

6. Create a **Security group** to allow  ports 22 and 80.

7. Create a **Network Interface** with an IP creating in the step 4.

8. Assign an **Elastic IP** to the **Network Interface** created in step 7.

9. Create an **Ubuntu Server** and **Install/Enable apache2** on it.