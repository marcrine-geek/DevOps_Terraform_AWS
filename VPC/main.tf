provider "aws" {
  region = "us-east-1"
}

resource aws_vpc "practice_vpc"{
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "dev"
  }
}

resource aws_subnet "public_subnet" {
  vpc_id = aws_vpc.practice_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "public"
  }
}

resource aws_subnet "private_subnet"{
  vpc_id = aws_vpc.practice_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "private"
  }
}

resource aws_subnet "public_subnetB"{
  vpc_id = aws_vpc.practice_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name" = "publicB"
  }
}

resource aws_subnet "private_subnetB"{
  vpc_id = aws_vpc.practice_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name" = "privateB"
  }
}

resource "aws_internet_gateway" "prac_igw" {
  vpc_id = aws_vpc.practice_vpc.id

  tags = {
    "Name" = "dev_igw"
  }
}

resource "aws_route_table" "prac_rtb" {
  vpc_id = aws_vpc.practice_vpc.id

  tags = {
    "Name" = "prac_rt"
  }
}

resource "aws_route" "prac_rt" {
  route_table_id = aws_route_table.prac_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.prac_igw.id

}

resource "aws_route_table_association" "prac_rtb_assoc" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.prac_rtb.id
}

resource "aws_ecr_repository" "prac_ecr" {
  name = "prac_ecr"
}

resource "aws_ecs_cluster" "prac_cluster" {
  name = "prac_cluster"
}

resource "aws_ecs_task_definition" "my_first_task" {
  family = "my_first_task"
  container_definitions = <<DEFINITION
  [
    {
      "name": "my_first_task",
      "image": "${aws_ecr_repository.prac_ecr.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "my_first_service" {
  name            = "my-first-service"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.prac_cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.my_first_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Setting the number of containers we want deployed to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.my_first_task.family}"
    container_port   = 3000 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_subnet.public_subnet.id}", "${aws_subnet.public_subnetB.id}"]
    assign_public_ip = true # Providing our containers with public IPs
  }
}

resource "aws_alb" "application_load_balancer" {
  name               = "test-lb-tf" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_subnet.public_subnet.id}",
    "${aws_subnet.public_subnetB.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.practice_vpc.id
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_vpc.practice_vpc.id}" # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our tagrte group
  }
}


